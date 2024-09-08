resource "aws_vpc" "ekscape" {
  cidr_block = var.cidr_block
  instance_tenancy = "default"
  enable_dns_hostnames = true
  assign_generated_ipv6_cidr_block = true

  tags = {
    Name = "${var.project}-${var.env}-vpc"
  }

}

data "aws_availability_zones" "available_zones" {}

resource "aws_subnet" "ekscape-pub-sub1" {
  vpc_id = aws_vpc.ekscape.id
  cidr_block = var.public_subnet1
  map_public_ip_on_launch = true
  availability_zone = data.aws_availability_zones.available_zones.names[0]
  assign_ipv6_address_on_creation = true
  ipv6_cidr_block = cidrsubnet(aws_vpc.ekscape.ipv6_cidr_block, 8, 1)  //Read more in `Docs/technical-docs.md`

  tags = {
    Name = "${var.project}- ${var.env}-public-sub-1"
  }
}

resource "aws_subnet" "ekscape-pub-sub2" {
  vpc_id = aws_vpc.ekscape.id
  cidr_block = var.public_subnet2
  map_public_ip_on_launch = true
  availability_zone = data.aws_availability_zones.available_zones.names[1]
  assign_ipv6_address_on_creation = true
  ipv6_cidr_block = cidrsubnet(aws_vpc.ekscape.ipv6_cidr_block, 8, 2)


  tags = {
    Name = "${var.project}- ${var.env}-public-sub-2"
  }
}

resource "aws_internet_gateway" "ekscape-igw" {
  vpc_id = aws_vpc.ekscape.id

  tags = {
    Name = "${var.project}- ${var.env}-igw"
  }
}


resource "aws_route_table" "ekscape-rtb" {
  vpc_id = aws_vpc.ekscape.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ekscape-igw.id
  }
  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.ekscape-igw.id
  }
}

resource "aws_route_table_association" "ekscape_pub_sub1_assoc" {
  subnet_id      = aws_subnet.ekscape-pub-sub1.id
  route_table_id = aws_route_table.ekscape-rtb.id
}

resource "aws_route_table_association" "ekscape-pub_sub2_assoc" {
  subnet_id      = aws_subnet.ekscape-pub-sub2.id
  route_table_id = aws_route_table.ekscape-rtb.id
}