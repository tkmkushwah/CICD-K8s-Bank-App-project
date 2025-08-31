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
  count = 2
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

  egress {     //Inbound: Fully closed (blocked).
    from_port   = 0 
    to_port     = 0  //all ports are allowed.
    protocol    = "-1" //all protocols are allowed.
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

  ingress {    //Outbound: Fully open (unrestricted).
    from_port   = 0
    to_port     = 0 //all ports are allowed.
    protocol    = "-1" //all protocols are allowed.
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
      Name = "devopstkm-node-sg"
    }
  }

