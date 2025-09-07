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
