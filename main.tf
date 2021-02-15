terraform {
  backend "s3" {
    bucket  = "austburn.me"
    key     = "austburn.me"
    region  = "us-east-2"
  }
}

provider "aws" {
  region = "${var.region}"
}


resource "aws_s3_bucket" "blog" {
  bucket = "blog.austburn.me"
  acl    = "public-read"
  policy = "${file("${path.module}/files/s3-policy.json")}"

  website {
    index_document = "index.html"
    error_document = "404.html"

    routing_rules = <<EOF
[{
    "Condition": {
        "KeyPrefixEquals": "/"
    },
    "Redirect": {
        "ReplaceKeyPrefixWith": "index.html"
    }
}]
EOF
}

  versioning {
    enabled = true
  }
}

resource "aws_cloudfront_distribution" "blog_distro" {
  origin {
    domain_name   = "${aws_s3_bucket.blog.bucket_domain_name}"
    origin_id     = "S3-blog.austburn.me"
    s3_origin_config {
      origin_access_identity = "origin-access-identity/cloudfront/E3P6W9J7WP1FCM"
    }
  }

  enabled         = true
  is_ipv6_enabled = true
  default_root_object = "index.html"
  aliases = ["austburn.me"]
  price_class = "PriceClass_100"

  default_cache_behavior {
    target_origin_id = "S3-blog.austburn.me"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    default_ttl = 300
    min_ttl = 0
    max_ttl = 31536000
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = "arn:aws:acm:us-east-1:296307749888:certificate/93cb4935-b4c2-413d-8d21-1dbf75b9d8f9"
    minimum_protocol_version = "TLSv1.1_2016"
    ssl_support_method = "sni-only"
  }
}
