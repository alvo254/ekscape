variable "vpc_id" {
  description = "The vpc id to associate the sg with"
  type        = string
}

variable "project" {
  default = "ekscape"
}

variable "env" {
  default = "ekscape"
}