output "vpc_id" {
  value = aws_vpc.ekscape.id
}

output "pub_sub1" {
  value = aws_subnet.ekscape-pub-sub1.id
}

output "pub_sub2" {
  value = aws_subnet.ekscape-pub-sub2.id
}

output "vpc_ipv6_cidr_block" {
  value = aws_vpc.ekscape.ipv6_cidr_block
}

output "vpc_cidr_block" {
  value = aws_vpc.ekscape.cidr_block
}