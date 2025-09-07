provider "aws" {
  region = "ap-south-1"
}

//create vpc 
resource "aws_vpc" "devopstkm_vpc" {
  cidr_block = "10.0.0.0/16" // vpc cidr ip range 65536 ips
  tags = {
    Name = "devopstkm-vpc"
  }
}

//create 2 subnets
resource "aws_subnet" "devopstkm_subnet" {
  count                   = 2
  vpc_id                  = aws_vpc.devopstkm_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.devopstkm_vpc.cidr_block, 8, count.index) // 256 ips in each subnet //cidrsubnet( base CIDR block , +newbits, subnetIndex)
  availability_zone       = element(["ap-south-1a", "ap-south-1b"], count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "devopstkm-subnet-${count.index}"
  }
}

//create internet gateway
resource "aws_internet_gateway" "devopstkm_igw" {
  vpc_id = aws_vpc.devopstkm_vpc.id

  tags = {
    Name = "devopstkm-igw"
  }
}

//create route table
resource "aws_route_table" "devopstkm_route_table" {
  vpc_id = aws_vpc.devopstkm_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.devopstkm_igw.id
  }
  tags = {
    Name = "devopstkm-route-table"
  }
}
//associate route table with subnets
resource "aws_route_table_association" "a" {
  count          = 2
  subnet_id      = aws_subnet.devopstkm_subnet[count.index].id
  route_table_id = aws_route_table.devopstkm_route_table.id
}


//This SG is attached to the EKS Cluster control plane.
//Egress open so the cluster control plane can communicate with the internet and AWS services.
//	No ingress so no inbound traffic allowed, so the control plane is protected.
//Basically minimal exposure for the control plane.

resource "aws_security_group" "devopstkm_cluster_sg" {
  vpc_id = aws_vpc.devopstkm_vpc.id

  egress { //Inbound: Fully closed (blocked).
    from_port   = 0
    to_port     = 0             //all ports are allowed.
    protocol    = "-1"          //all protocols are allowed.
    cidr_blocks = ["0.0.0.0/0"] // all IPs are allowed.
  }

  tags = {
    Name = "devopstkm-cluster-sg"
  }
}

//This SG is attached to the EKS worker nodes.
//Egress open so the worker nodes can communicate with the internet and AWS services.
//Ingress open so the worker nodes can receive traffic from the internet and the cluster control plane.

resource "aws_security_group" "devopstkm_node_sg" {
  vpc_id = aws_vpc.devopstkm_vpc.id

  ingress { //Outbound: Fully open (unrestricted).
    from_port   = 0
    to_port     = 0    //all ports are allowed.
    protocol    = "-1" //all protocols are allowed.
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "devopstkm-node-sg"
  }
}

# When we create an EKS cluster, AWS runs a control plane (managed by AWS).
# That control plane needs permissions to talk to AWS resources (like networking, load balancers, worker nodes, etc.).

# So, we create an IAM Role and attach policies (like AmazonEKSClusterPolicy) to it.

# Eks controle plane is not inside the vpc it is managed by aws 
# why subnets are required then?
# Actualy it connects with vpc using ENIs (Elastic network interfaces)
# so aws needs to know in which subnets it can create those ENIs.
# The ENIs allow our worker nodes (in our VPC) to talk to the control plane.
# If we pass two subnets, AWS will create ENIs in both subnets (for High Availability ).
# The security group we give here controls traffic between the control plane and our worker nodes


#                     AWS Managed EKS Control Plane
#                    (API Server, etcd, etc.)
#                               │
#                               │ Communicates via ENIs
#                               ▼
#         ┌────────────────────────────────────────┐
#         │                 Your VPC               │
#         │                                        │
#         │  ┌─────────────┐        ┌─────────────┐│
#         │  │ Subnet 1    │        │ Subnet 2    ││
#         │  │ (private)   │        │ (private)   ││
#         │  │ ENI attached│        │ ENI attached││
#         │  │ Security    │        │ Security    ││
#         │  │ Group: sg-1 │        │ Group: sg-1 ││
#         │  └─────┬──────┘        └─────┬──────┘. │
#         │        │ Worker Nodes (EC2 instances)  │
#         │        │ kubectl / kubelet connects    │ 
#         │        ▼                               │ 
#         │    Node Group                          │
#         └─────────────────────────────────────┘

//create EKS cluster 
resource "aws_eks_cluster" "devopstkm" {
  name     = "devopstkm-cluster"
  role_arn = aws_iam_role.devopstkm_cluster_role.arn //Hey EKS cluster, use this IAM Role (its ARN) for your permissions.
  vpc_config {
    subnet_ids         = aws_subnet.devopstkm_subnet[*].id
    security_group_ids = [aws_security_group.devopstkm_cluster_sg.id]
  }
}


//Create node Group (Worker Nodes): These are the actual servers (EC2 instances in AWS) where our pods run.
resource "aws_eks_node_group" "devopstkm" {
  cluster_name    = aws_eks_cluster.devopstkm.name
  node_group_name = "devopstkm-node-group"
  node_role_arn   = aws_iam_role.devopstkm_node_group_role.arn //Hey EKS node group, use this IAM Role (its ARN) for your permissions.
  subnet_ids      = aws_subnet.devopstkm_subnet[*].id          //Hey EKS node group, launch worker nodes in these subnets.
  scaling_config {
    desired_size = 3 //number of worker nodes
    max_size     = 3 //max number of worker nodes
    min_size     = 3 //min number of worker nodes
  }
  instance_types = ["t2.large"] //2 vCPU and 8 GiB memory

  remote_access {                                                         // Enable SSH access to the worker nodes
    ec2_ssh_key               = var.ssh_key_name                          //name of the ssh key pair
    source_security_group_ids = [aws_security_group.devopstkm_node_sg.id] //security group which allows inbound traffic
  }
}

resource "aws_iam_role" "devopstkm_cluster_role" {
  name = "devopstkm-cluster-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}
//Attach the AmazonEKSClusterPolicy to the IAM Role
resource "aws_iam_role_policy_attachment" "devopstkm_cluster_role_policy" {
  role       = aws_iam_role.devopstkm_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}
resource "aws_iam_role" "devopstkm_node_group_role" {
  name = "devopstkm-node-group-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}
//Attach the required policies to the IAM Role
resource "aws_iam_role_policy_attachment" "devopstkm_node_group_role_policy" {
  role       = aws_iam_role.devopstkm_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
//Policy for the CNI plugin to manage networking resources on your behalf.
resource "aws_iam_role_policy_attachment" "devopstkm_cni_policy" {
  role       = aws_iam_role.devopstkm_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
//Policy to allow nodes to pull container images from Amazon ECR
resource "aws_iam_role_policy_attachment" "devopstkm_node_group_registry_policy" {
  role       = aws_iam_role.devopstkm_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
