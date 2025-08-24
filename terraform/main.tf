# -------------------------------
# S3 for static assets
# -------------------------------
resource "aws_s3_bucket" "assets" {
  bucket = "${var.name_prefix}-assets-${var.environment}"
}

# -------------------------------
# CloudFront distribution (fixed)
# -------------------------------
resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "OAI for ${var.project}"
}

resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  comment             = "Retail CDN (dry-run)"
  default_root_object = "index.html"

  # FIXED: Use `origin` instead of `origins`
  origin {
    domain_name = "${aws_s3_bucket.assets.bucket}.s3.amazonaws.com"
    origin_id   = "s3-origin"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3-origin"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# -------------------------------
# Application Load Balancer (ALB)
# -------------------------------
resource "aws_lb" "app" {
  name               = "${var.name_prefix}-alb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  subnets            = var.public_subnet_ids
}

resource "aws_lb_target_group" "web_tg" {
  name     = "${var.name_prefix}-tg-${var.environment}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    interval            = 30
    path                = "/healthz"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    matcher             = "200-399"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

# -------------------------------
# Auto Scaling Group (EC2)
# -------------------------------
resource "aws_launch_template" "web" {
  name_prefix   = "${var.name_prefix}-lt-"
  image_id      = "ami-0123456789abcdef0" # placeholder
  instance_type = "t3.micro"

  user_data = base64encode("#!/bin/bash\n echo 'hello retail' > /var/www/html/index.html\n")
}

resource "aws_autoscaling_group" "web_asg" {
  name                      = "${var.name_prefix}-asg-${var.environment}"
  max_size                  = 4
  min_size                  = 2
  desired_capacity          = 2
  vpc_zone_identifier       = var.private_subnet_ids
  health_check_type         = "EC2"
  health_check_grace_period = 60

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.web_tg.arn]
}

# -------------------------------
# RDS (Multi-AZ) — placeholder IDs
# -------------------------------
resource "aws_db_subnet_group" "db" {
  name       = "${var.name_prefix}-dbsubnet-${var.environment}"
  subnet_ids = var.private_subnet_ids
}

resource "aws_db_instance" "app_db" {
  identifier                 = "${var.name_prefix}-db-${var.environment}"
  engine                     = "postgres"
  engine_version             = "15.3"
  instance_class             = "db.t3.micro"
  allocated_storage          = 20
  multi_az                   = true
  username                   = "admin"
  password                   = "ChangeMe_OnlyIfApplying!"
  db_subnet_group_name       = aws_db_subnet_group.db.name
  skip_final_snapshot        = true
  publicly_accessible        = false
  auto_minor_version_upgrade = true
}

# -------------------------------
# (Optional) EKS — disabled by default
# -------------------------------
# resource "aws_eks_cluster" "this" {
#   count    = var.enable_eks ? 1 : 0
#   name     = "${var.name_prefix}-eks-${var.environment}"
#   role_arn = "arn:aws:iam::123456789012:role/placeholder-cluster-role"
#   vpc_config {
#     subnet_ids = var.private_subnet_ids
#   }
# }
#
# resource "aws_eks_node_group" "ng" {
#   count = var.enable_eks ? 1 : 0
#   cluster_name    = aws_eks_cluster.this[0].name
#   node_group_name = "${var.name_prefix}-ng-${var.environment}"
#   node_role_arn   = "arn:aws:iam::123456789012:role/placeholder-node-role"
#   subnet_ids      = var.private_subnet_ids
#   scaling_config {
#     desired_size = 2
#     max_size     = 4
#     min_size     = 2
#   }
#   instance_types = ["t3.small"]
# }

output "dryrun_summary" {
  value = {
    s3_bucket_name    = aws_s3_bucket.assets.bucket
    cloudfront_domain = aws_cloudfront_distribution.cdn.domain_name
    alb_dns           = aws_lb.app.dns_name
    asg_name          = aws_autoscaling_group.web_asg.name
    rds_identifier    = aws_db_instance.app_db.identifier
    eks_enabled       = false
  }
}
resource "aws_autoscaling_group" "web_asg" {
  name                      = "${var.name_prefix}-asg-${var.environment}"
  max_size                  = 4
  min_size                  = 2
  desired_capacity          = 2
  vpc_zone_identifier       = var.private_subnet_ids
  health_check_type         = "EC2"
  health_check_grace_period = 60

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.web_tg.arn]

  # --- add required tags (propagate to instances for visibility) ---
  tag {
    key                 = "Project"
    value               = var.project
    propagate_at_launch = true
  }
  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
  tag {
    key                 = "Owner"
    value               = "dry-run-demo"
    propagate_at_launch = true
  }
  tag {
    key                 = "CostCenter"
    value               = "simulation-only"
    propagate_at_launch = true
  }
}

