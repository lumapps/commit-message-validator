use crate::error::ValidationError;
use crate::patterns;

#[derive(Debug, Default, PartialEq, Eq)]
pub struct ParsedMessage {
    pub header: String,
    pub body: String,
    pub jira: String,
    pub footer: String,
}

#[derive(PartialEq)]
enum State {
    WaitingHeader,
    WaitingEmpty,
    StartText,
    ReadingBody,
    ReadingBroken,
    ReadingFooter,
}

fn structure(msg: &str) -> ValidationError {
    ValidationError::Structure(msg.to_string())
}

pub fn parse(message: &str, jira_in_header: bool) -> Result<ParsedMessage, ValidationError> {
    let mut parsed = ParsedMessage::default();
    let mut state = State::WaitingHeader;

    for line in message.split('\n') {
        match state {
            State::WaitingHeader => {
                parsed.header = line.to_string();
                state = State::WaitingEmpty;
                if jira_in_header {
                    if let Some(caps) = patterns::JIRA_HEADER.captures(line) {
                        parsed.jira = caps[1].to_string();
                    }
                }
            }
            State::WaitingEmpty => {
                if !line.is_empty() {
                    return Err(structure(
                        "missing empty line in commit message between header and body or body and footer",
                    ));
                }
                state = State::StartText;
            }
            State::StartText => {
                if line.is_empty() {
                    return Err(structure("double empty line is not allowed"));
                }
                if patterns::BROKE.is_match(line) {
                    state = State::ReadingFooter;
                } else if patterns::JIRA_FOOTER.is_match(line) {
                    state = State::ReadingBroken;
                    parsed.jira = line.to_string();
                } else {
                    state = State::ReadingBody;
                    parsed.body.push_str(line);
                    parsed.body.push('\n');
                }
            }
            State::ReadingBody => {
                if patterns::BROKE.is_match(line) {
                    return Err(structure("missing empty line before broke part"));
                }
                if patterns::JIRA_FOOTER.is_match(line) {
                    return Err(structure("missing empty line before JIRA reference"));
                }
                if line.is_empty() {
                    state = State::StartText;
                } else {
                    parsed.body.push_str(line);
                    parsed.body.push('\n');
                }
            }
            State::ReadingBroken => {
                if patterns::BROKE.is_match(line) {
                    state = State::ReadingFooter;
                } else {
                    return Err(structure(
                        "only broken part could be after the JIRA reference",
                    ));
                }
            }
            State::ReadingFooter => {
                if line.is_empty() {
                    return Err(structure("no empty line allowed in broken part"));
                }
                parsed.footer.push_str(line);
                parsed.footer.push('\n');
            }
        }
    }

    if state == State::StartText {
        return Err(structure(
            "new line at the end of the commit is not allowed",
        ));
    }

    Ok(parsed)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn ok(msg: &str, jira_in_header: bool) -> ParsedMessage {
        parse(msg, jira_in_header).expect("expected valid structure")
    }

    fn err_code(msg: &str) -> i32 {
        parse(msg, false)
            .expect_err("expected structure error")
            .code()
    }

    #[test]
    fn structure_errors() {
        // one trailing line
        assert_eq!(err_code("plop plop\n"), 1);
        // missing empty line after header (body)
        assert_eq!(err_code("plop plop\nplop\n\nplop\n"), 1);
        // missing empty line after header (jira)
        assert_eq!(err_code("plop plop\nABC-1234\n"), 1);
        // missing empty line after header (broken)
        assert_eq!(err_code("plop plop\nBROKEN:\n"), 1);
        // missing empty line after body with jira ref
        assert_eq!(
            err_code("plop plop\n\nplop\nplop\nplop\nplop\nLUM-1234\n"),
            1
        );
        // missing empty line after body with broken
        assert_eq!(
            err_code("plop plop\n\nplop\nplop\nplop\nplop\nBROKEN:\n"),
            1
        );
        // empty line after the body (double empty)
        assert_eq!(err_code("plop plop\n\nplop\nplop\nplop\nplop\n\n"), 1);
    }

    #[test]
    fn header_only() {
        let p = ok("plop plop", false);
        assert_eq!(
            p,
            ParsedMessage {
                header: "plop plop".into(),
                ..Default::default()
            }
        );
    }

    #[test]
    fn header_and_jira() {
        let p = ok("plop plop\n\nABC-1234", false);
        assert_eq!(p.header, "plop plop");
        assert_eq!(p.jira, "ABC-1234");
        assert_eq!(p.body, "");
        assert_eq!(p.footer, "");
    }

    #[test]
    fn jira_in_header_extracted() {
        let p = ok("feat(abc): ABC-1234\n\nplop", true);
        assert_eq!(p.header, "feat(abc): ABC-1234");
        assert_eq!(p.jira, "ABC-1234");
        assert_eq!(p.body, "plop\n");
    }

    #[test]
    fn header_and_multiple_jira() {
        let p = ok("plop plop\n\nABC-1234 DE-1234", false);
        assert_eq!(p.jira, "ABC-1234 DE-1234");
    }

    #[test]
    fn header_and_broken() {
        let p = ok("plop plop\n\nBROKEN:\n- plop\n- plop", false);
        assert_eq!(p.footer, "- plop\n- plop\n");
        assert_eq!(p.body, "");
    }

    #[test]
    fn header_jira_and_broken() {
        let p = ok("plop plop\n\nABC-1234\nBROKEN:\n- plop\n- plop", false);
        assert_eq!(p.jira, "ABC-1234");
        assert_eq!(p.footer, "- plop\n- plop\n");
    }

    #[test]
    fn header_and_body() {
        let p = ok("plop plop\n\nhello", false);
        assert_eq!(p.body, "hello\n");
    }

    #[test]
    fn multiline_body() {
        let p = ok("plop plop\n\nhello\n\nplopplop\nplopplop\n\ntoto", false);
        assert_eq!(p.body, "hello\nplopplop\nplopplop\ntoto\n");
    }

    #[test]
    fn multiline_body_and_jira() {
        let p = ok(
            "plop plop\n\nhello\n\nplopplop\nplopplop\n\ntoto\n\nABC-1234",
            false,
        );
        assert_eq!(p.body, "hello\nplopplop\nplopplop\ntoto\n");
        assert_eq!(p.jira, "ABC-1234");
    }

    #[test]
    fn multiline_body_and_broken() {
        let p = ok(
            "plop plop\n\nhello\n\nplopplop\nplopplop\n\ntoto\n\nBROKEN:\n- plop\n- plop",
            false,
        );
        assert_eq!(p.body, "hello\nplopplop\nplopplop\ntoto\n");
        assert_eq!(p.footer, "- plop\n- plop\n");
    }

    #[test]
    fn multiline_body_jira_and_broken() {
        let p = ok(
            "plop plop\n\nhello\n\nplopplop\nplopplop\n\ntoto\n\nABC-1234\nBROKEN:\n- plop\n- plop",
            false,
        );
        assert_eq!(p.body, "hello\nplopplop\nplopplop\ntoto\n");
        assert_eq!(p.jira, "ABC-1234");
        assert_eq!(p.footer, "- plop\n- plop\n");
    }

    #[test]
    fn only_broken_allowed_after_jira() {
        // JIRA ref then a non-broken line -> structure error
        assert_eq!(err_code("plop plop\n\nABC-1234\nnope"), 1);
    }

    #[test]
    fn no_empty_line_in_broken_part() {
        assert_eq!(err_code("plop plop\n\nBROKEN:\n- plop\n\n- plop"), 1);
    }
}
