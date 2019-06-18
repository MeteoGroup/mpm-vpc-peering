resource "aws_vpc_peering_connection" "this" {
  count       = "${var.enabled == "true" ? 1 : 0}"
  vpc_id      = "${join("", data.aws_vpc.requestor.*.id)}"
  peer_vpc_id = "${join("", data.aws_vpc.acceptor.*.id)}"

  auto_accept = "${var.auto_accept}"

  accepter {
    allow_remote_vpc_dns_resolution = "${var.acceptor_allow_remote_vpc_dns_resolution}"
  }

  requester {
    allow_remote_vpc_dns_resolution = "${var.requestor_allow_remote_vpc_dns_resolution}"
  }

  tags = "${var.tags}"
}

# Lookup requestor VPC so that we can reference the CIDR
data "aws_vpc" "requestor" {
  count = "${var.enabled == "true" ? 1 : 0}"
  id    = "${var.requestor_vpc_id}"
  tags  = "${var.requestor_vpc_tags}"
}

# Lookup requestor route tables
data "aws_route_table" "requestor" {
  count     = "${var.enabled == "true" ? length(distinct(sort(data.aws_subnet_ids.requestor.ids))) : 0}"
  subnet_id = "${element(distinct(sort(data.aws_subnet_ids.requestor.ids)), count.index)}"
}

# Lookup requestor subnets
data "aws_subnet_ids" "requestor" {
  count  = "${var.enabled == "true" ? 1 : 0}"
  vpc_id = "${data.aws_vpc.requestor.id}"
}

# Lookup acceptor VPC so that we can reference the CIDR
data "aws_vpc" "acceptor" {
  count = "${var.enabled == "true" ? 1 : 0}"
  id    = "${var.acceptor_vpc_id}"
  tags  = "${var.acceptor_vpc_tags}"
}

# Lookup acceptor subnets
data "aws_subnet_ids" "acceptor" {
  count  = "${var.enabled == "true" ? 1 : 0}"
  vpc_id = "${data.aws_vpc.acceptor.id}"
}

# Lookup acceptor route tables
data "aws_route_table" "acceptor" {
  count     = "${var.enabled == "true" ? length(distinct(sort(data.aws_subnet_ids.acceptor.ids))) : 0}"
  subnet_id = "${element(distinct(sort(data.aws_subnet_ids.acceptor.ids)), count.index)}"
}

# Create routes from requestor to acceptor
resource "aws_route" "requestor" {
  count                     = "${var.enabled == "true" ? length(distinct(sort(data.aws_route_table.requestor.*.route_table_id))) * length(data.aws_vpc.acceptor.cidr_block_associations) : 0}"
  route_table_id            = "${element(distinct(sort(data.aws_route_table.requestor.*.route_table_id)), (ceil(count.index / (length(data.aws_vpc.acceptor.cidr_block_associations)))))}"
  destination_cidr_block    = "${lookup(data.aws_vpc.acceptor.cidr_block_associations[count.index % (length(data.aws_vpc.acceptor.cidr_block_associations))], "cidr_block")}"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.this.id}"
  depends_on                = ["data.aws_route_table.requestor", "aws_vpc_peering_connection.this"]
}

# Create routes from acceptor to requestor
resource "aws_route" "acceptor" {
  count                     = "${var.enabled == "true" ? length(distinct(sort(data.aws_route_table.acceptor.*.route_table_id))) * length(data.aws_vpc.requestor.cidr_block_associations) : 0}"
  route_table_id            = "${element(distinct(sort(data.aws_route_table.acceptor.*.route_table_id)), ceil(count.index / (length(data.aws_vpc.requestor.cidr_block_associations))))}"
  destination_cidr_block    = "${lookup(data.aws_vpc.requestor.cidr_block_associations[count.index % (length(data.aws_vpc.requestor.cidr_block_associations))], "cidr_block")}"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.this.id}"
  depends_on                = ["data.aws_route_table.acceptor", "aws_vpc_peering_connection.this"]
}
