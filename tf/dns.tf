resource "aws_route53_zone" "austburn" {
  name = "austburn.me"
}

resource "aws_route53_record" "alb_record" {
  zone_id = "${aws_route53_zone.austburn.zone_id}"
  name    = "austburn.me"
  type    = "A"

  alias {
    name                   = "${aws_alb.web.dns_name}"
    zone_id                = "${aws_alb.web.zone_id}"
    evaluate_target_health = true
  }
}
