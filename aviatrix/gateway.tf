resource "aviatrix_spoke_gateway" "spoke_gateway_1" {
    cloud_type = 1
    account_name = "aws-account"
    gw_name = "ekscape"
    vpc_id = "vpc-0d92ea51f3b1ed461~~ekscape-prod-vpc"
    vpc_reg = "us-east-1 (N. Virginia)"
    gw_size = "t3.small"
    subnet = "172.16.0.0/22"
    manage_ha_gateway = false
}

resource "aviatrix_spoke_ha_gateway" "spoke_ha_gateway_1" {
    primary_gw_name = "ekscape"
    subnet = "172.16.8.0/22"
    depends_on = [ 
        aviatrix_spoke_gateway.spoke_gateway_1
    ]
}

