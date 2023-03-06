resource "aws_route53_zone" "austburn" {
  name = "austburn.me"
}

resource "aws_route53_record" "alb_record" {
  zone_id = aws_route53_zone.austburn.zone_id
  name    = "austburn.me"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.blog_distro.domain_name
    zone_id                = aws_cloudfront_distribution.blog_distro.hosted_zone_id
    evaluate_target_health = true
  }
}

resource "aws_acm_certificate" "cert" {
  provider = aws.east1
  domain_name = "austburn.me"
  subject_alternative_names = ["*.austburn.me"]
}
