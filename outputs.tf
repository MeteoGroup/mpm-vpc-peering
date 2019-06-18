output "connection_id" {
  value       = "${join("", aws_vpc_peering_connection.this.*.id)}"
  description = "VPC peering connection ID"
}

output "accept_status" {
  value       = "${join("", aws_vpc_peering_connection.this.*.accept_status)}"
  description = "The status of the VPC peering connection request"
}
