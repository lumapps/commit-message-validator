use crate::config::Config;
use crate::error::ValidationError;
use crate::patterns;

#[derive(Debug)]
pub enum HeaderKind {
    Temp,
    Revert,
    Conventional {
        type_: String,
        scope: String,
        subject: String,
    },
}

pub fn classify_header(header: &str, config: &Config) -> Result<HeaderKind, ValidationError> {
    if config.allow_temp && patterns::TEMP_HEADER.is_match(header) {
        Ok(HeaderKind::Temp)
    } else if patterns::REVERT_HEADER.is_match(header) {
        Ok(HeaderKind::Revert)
    } else if let Some(caps) = patterns::HEADER.captures(header) {
        Ok(HeaderKind::Conventional {
            type_: caps[1].to_string(),
            scope: caps[2].to_string(),
            subject: caps[3].to_string(),
        })
    } else {
        Err(ValidationError::Header(
            "commit header doesn't match overall header pattern: 'type(scope): message'"
                .to_string(),
        ))
    }
}

pub fn header_length(header: &str, max: usize) -> Result<(), ValidationError> {
    if header.chars().count() > max {
        return Err(ValidationError::HeaderLength(format!(
            "commit header length is more than {max} characters"
        )));
    }
    Ok(())
}

pub fn commit_type(type_: &str) -> Result<(), ValidationError> {
    if patterns::TYPE.is_match(type_) {
        Ok(())
    } else {
        Err(ValidationError::Type(format!(
            "commit type '{type_}' is unknown"
        )))
    }
}

pub fn scope(scope: &str) -> Result<(), ValidationError> {
    if patterns::SCOPE.is_match(scope) {
        Ok(())
    } else {
        Err(ValidationError::Scope(format!(
            "commit scope '{scope}' is not kebab-case"
        )))
    }
}

pub fn subject(subject: &str) -> Result<(), ValidationError> {
    if patterns::SUBJECT.is_match(subject) {
        Ok(())
    } else {
        Err(ValidationError::Subject(format!(
            "commit subject '{subject}' should not end with a '.'"
        )))
    }
}

pub fn body_length(text: &str, max: usize) -> Result<(), ValidationError> {
    for line in text.split('\n') {
        // Skip lines with no whitespace as they can't be wrapped.
        if !line.contains(|c: char| c.is_ascii_whitespace()) {
            continue;
        }
        if line.chars().count() > max {
            return Err(ValidationError::BodyLength(format!(
                "body message line length is more than {max} characters"
            )));
        }
    }
    Ok(())
}

pub fn trailing_space(text: &str) -> Result<(), ValidationError> {
    for line in text.split('\n') {
        if patterns::TRAILING_SPACE.is_match(line) {
            return Err(ValidationError::TrailingSpace(
                "body message must not have trailing spaces".to_string(),
            ));
        }
    }
    Ok(())
}

pub fn need_jira(type_: &str, config: &Config) -> bool {
    if config.no_jira {
        return false;
    }
    config.jira_types.iter().any(|t| t == type_)
}

pub fn jira(type_: &str, jira: &str, config: &Config) -> Result<(), ValidationError> {
    if need_jira(type_, config) && jira.is_empty() {
        return Err(ValidationError::Jira(format!(
            "commits with type '{type_}' need to include a reference to a JIRA ticket, by adding the project prefix and the issue number to the commit message, this could be done easily with: git commit -m 'feat(widget): add a wonderful widget' -m LUM-1234"
        )));
    }
    Ok(())
}

pub fn revert(body: &str, config: &Config) -> Result<(), ValidationError> {
    if config.no_revert_sha1 {
        return Ok(());
    }
    let has_sha = body
        .split('\n')
        .any(|line| patterns::REVERT_COMMIT.is_match(line));
    if has_sha {
        Ok(())
    } else {
        Err(ValidationError::Revert(
            "revert commit should contain the reverted sha1".to_string(),
        ))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::config::Config;

    fn cfg() -> Config {
        Config::default()
    }

    #[test]
    fn classify_rejects_malformed_headers() {
        for bad in [
            "type",
            "type(scope)",
            "type(scope) message",
            "type(scope) : message",
            "type(scope: message",
            "type scope: message",
            "type(scope):message",
        ] {
            assert_eq!(classify_header(bad, &cfg()).unwrap_err().code(), 2, "{bad}");
        }
    }

    #[test]
    fn classify_temp_only_when_allowed() {
        let mut c = cfg();
        assert_eq!(classify_header("fixup! x", &c).unwrap_err().code(), 2);
        assert_eq!(classify_header("squash! x", &c).unwrap_err().code(), 2);
        c.allow_temp = true;
        assert!(matches!(
            classify_header("fixup! x", &c).unwrap(),
            HeaderKind::Temp
        ));
        assert!(matches!(
            classify_header("squash! x", &c).unwrap(),
            HeaderKind::Temp
        ));
    }

    #[test]
    fn classify_revert() {
        assert!(matches!(
            classify_header("revert: type(scope): message", &cfg()).unwrap(),
            HeaderKind::Revert
        ));
        assert!(matches!(
            classify_header("Revert \"type(scope): message\"", &cfg()).unwrap(),
            HeaderKind::Revert
        ));
    }

    #[test]
    fn classify_conventional_extracts_parts() {
        let k = classify_header("type(scope): message", &cfg()).unwrap();
        match k {
            HeaderKind::Conventional {
                type_,
                scope,
                subject,
            } => {
                assert_eq!(type_, "type");
                assert_eq!(scope, "scope");
                assert_eq!(subject, "message");
            }
            _ => panic!("expected conventional"),
        }
    }

    #[test]
    fn header_length_boundary() {
        let at = "0".repeat(100);
        let over = "0".repeat(101);
        assert!(header_length(&at, 100).is_ok());
        assert_eq!(header_length(&over, 100).unwrap_err().code(), 3);
        assert!(header_length(&over, 150).is_ok());
    }

    #[test]
    fn commit_type_rules() {
        assert!(commit_type("feat").is_ok());
        assert_eq!(commit_type("plop").unwrap_err().code(), 4);
        assert_eq!(commit_type("feat ").unwrap_err().code(), 4);
        assert_eq!(commit_type("Feat").unwrap_err().code(), 4);
    }

    #[test]
    fn scope_rules() {
        assert!(scope("p2").is_ok());
        assert!(scope("pl2op-plop1-plop-0001").is_ok());
        for bad in ["", "plopPlop", "plop plop", "plop "] {
            assert_eq!(scope(bad).unwrap_err().code(), 5, "{bad}");
        }
    }

    #[test]
    fn subject_rules() {
        assert!(subject("0002 dedezf ef zefzef").is_ok());
        for bad in ["", "plop ", "plop."] {
            assert_eq!(subject(bad).unwrap_err().code(), 6, "{bad}");
        }
    }

    #[test]
    fn body_length_rules() {
        let over = "12345678 ".to_string() + &"0".repeat(93); // 102 chars, has a space
        assert_eq!(body_length(&over, 100).unwrap_err().code(), 7);
        // long line with no space is skipped
        let long_no_space = "0".repeat(260);
        assert!(body_length(&long_no_space, 100).is_ok());
        // 100-char line with space is fine
        let at = "12345678 ".to_string() + &"0".repeat(91); // 100 chars
        assert!(body_length(&at, 100).is_ok());
        assert!(body_length(&over, 150).is_ok());
    }

    #[test]
    fn trailing_space_rules() {
        assert_eq!(trailing_space("pdzofjzf ").unwrap_err().code(), 8);
        assert_eq!(
            trailing_space("\nrerer\n\n  \nLUM-2345")
                .unwrap_err()
                .code(),
            8
        );
        assert!(trailing_space("\nrerer\n\n\nLUM-2345").is_ok());
    }

    #[test]
    fn need_jira_rules() {
        let mut c = cfg();
        assert!(need_jira("feat", &c));
        assert!(need_jira("fix", &c));
        assert!(!need_jira("docs", &c));
        assert!(!need_jira("test", &c));
        c.no_jira = true;
        assert!(!need_jira("feat", &c));
    }

    #[test]
    fn jira_rules() {
        assert_eq!(jira("feat", "", &cfg()).unwrap_err().code(), 9);
        assert!(jira("lint", "", &cfg()).is_ok());
        assert!(jira("feat", "ABC-123", &cfg()).is_ok());
        assert!(jira("feat", "AB-123", &cfg()).is_ok());
    }

    #[test]
    fn revert_rules() {
        let no_sha = "rerer\n\nLUM-2345";
        let with_sha = "rerer\n\nThis reverts commit 1234567890.\n\nLUM-2345";
        assert_eq!(revert(no_sha, &cfg()).unwrap_err().code(), 10);
        assert!(revert(with_sha, &cfg()).is_ok());
        let mut c = cfg();
        c.no_revert_sha1 = true;
        assert!(revert(no_sha, &c).is_ok());
    }
}
