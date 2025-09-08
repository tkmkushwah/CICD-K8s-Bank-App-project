// Output the VPC ID
output "vpc_id" {
  value       = aws_vpc.devopstkm_vpc.id
  description = "The ID of the VPC"
}

// Output the EKS worker node SG ID
output "node_sg_id" {
  value       = aws_security_group.devopstkm_node_sg.id
  description = "Security group ID for the EKS worker nodes"
}

// Output the EKS cluster SG ID
output "cluster_sg_id" {
  value       = aws_security_group.devopstkm_cluster_sg.id
  description = "Security group ID for the EKS control plane"
}

// Output the Subnet IDs
output "subnet_ids" {
  value       = aws_subnet.devopstkm_subnet[*].id
  description = "List of all subnet IDs in the VPC"
}

//Internet Gateway ID for cleaning up resources after destroying the cluster
output "igw_id" {
  value       = aws_internet_gateway.devopstkm_igw.id
  description = "Internet Gateway ID"
}

// Route Table ID or cleaning up resources after destroying the cluster
output "route_table_id" {
  value       = aws_route_table.devopstkm_route_table.id
  description = "Route Table ID"
}

//node group id 
output "node_group_id" {
  value       = aws_eks_node_group.devopstkm.id
  description = "EKS Node Group ID"
}

//cluster id
output "cluster_id" {
  value       = aws_eks_cluster.devopstkm.id
  description = "EKS Cluster ID"
}
