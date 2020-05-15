resource "aws_internet_gateway" "cluster_igw" {
  vpc_id = aws_vpc.cluster_vpc.id

  tags = {
    "Name"                                      = "${local.stack_name}-InternetGateway"
    "aws:cloudformation:stack-name"             = local.stack_name
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

resource "aws_subnet" "cluster_subnet_public" {
  count = length(var.aws_availability_zones)

  vpc_id     = aws_vpc.cluster_vpc.id
  cidr_block = "10.0.1${count.index}.0/24"
  availability_zone = format(
    "%s%s",
    element([var.aws_region], count.index),
    element(var.aws_availability_zones, count.index),
  )
  map_public_ip_on_launch = true

  tags = {
    "Name"                                      = "${local.stack_name}-PublicSubnet${count.index + 1}"
    "aws:cloudformation:stack-name"             = local.stack_name
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

resource "aws_subnet" "cluster_subnet_private" {
  count = length(var.aws_availability_zones)

  vpc_id     = aws_vpc.cluster_vpc.id
  cidr_block = "10.0.2${count.index}.0/24"
  availability_zone = format(
    "%s%s",
    element([var.aws_region], count.index),
    element(var.aws_availability_zones, count.index),
  )
  map_public_ip_on_launch = false

  tags = {
    "Name"                                      = "${local.stack_name}-PrivateSubnet${count.index + 1}"
    "aws:cloudformation:stack-name"             = local.stack_name
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

resource "aws_eip" "cluster_ngw_eip" {
  count = length(var.aws_availability_zones)
  vpc   = true

  tags = {
    "Name"                                      = "${local.stack_name}-ngw-eip${count.index + 1}"
    "aws:cloudformation:stack-name"             = local.stack_name
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

resource "aws_nat_gateway" "cluster_nat_gateway" {
  count         = length(var.aws_availability_zones)
  allocation_id = aws_eip.cluster_ngw_eip[count.index].id
  subnet_id     = aws_subnet.cluster_subnet_public[count.index].id
  tags = {
    Name = "${var.cluster_name}-nat-gateway${count.index + 1}"
  }
  depends_on = [aws_internet_gateway.cluster_igw]
}

resource "aws_route_table" "cluster_rt_public" {
  vpc_id = aws_vpc.cluster_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cluster_igw.id
  }

  tags = {
    "Name"                          = "Public Subnet"
    "Network"                       = "Public"
    "aws:cloudformation:logical-id" = "PublicRouteTable"
    "aws:cloudformation:stack-name" = local.stack_name
  }
}

resource "aws_route_table_association" "cluster_rta_public" {
  count = length(var.aws_availability_zones)

  subnet_id      = aws_subnet.cluster_subnet_public[count.index].id
  route_table_id = aws_route_table.cluster_rt_public.id
}

resource "aws_route_table" "cluster_rt_private" {
  count  = length(var.aws_availability_zones)
  vpc_id = aws_vpc.cluster_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.cluster_nat_gateway[count.index].id
  }

  tags = {
    "Name"                          = "Private Subnet${count.index}"
    "Network"                       = "Private${count.index}"
    "aws:cloudformation:logical-id" = "PrivateRouteTable"
    "aws:cloudformation:stack-name" = local.stack_name
  }
}

resource "aws_route_table_association" "cluster_route_association" {
  count = length(var.aws_availability_zones)

  subnet_id      = aws_subnet.cluster_subnet_private[count.index].id
  route_table_id = aws_route_table.cluster_rt_private[count.index].id
}

