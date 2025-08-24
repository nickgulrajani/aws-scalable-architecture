variable "project" {
  description = "Project name"
  type        = string
  default     = "retail-scale"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dryrun"
}

variable "aws_region" {
  description = "Region for the dry run (no calls will be made)"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "retail"
}

variable "vpc_id" {
  description = "Placeholder VPC ID (not used against AWS in dry run)"
  type        = string
  default     = "vpc-1234567890abcdef0"
}

variable "public_subnet_ids" {
  description = "Placeholder public subnets for ALB/CloudFront origins"
  type        = list(string)
  default     = ["subnet-11111111", "subnet-22222222"]
}

variable "private_subnet_ids" {
  description = "Placeholder private subnets for ASG/RDS/EKS"
  type        = list(string)
  default     = ["subnet-aaaaaaa1", "subnet-bbbbbbb2"]
}

variable "enable_eks" {
  description = "Whether to include EKS resources (disabled for dry run)"
  type        = bool
  default     = false
}
