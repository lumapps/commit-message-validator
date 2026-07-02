pub mod config;
pub mod error;
mod parser;
mod patterns;
mod validate;

pub use config::{Config, Overrides};
pub use error::ValidationError;

use validate::HeaderKind;

#[derive(Debug, PartialEq, Eq)]
pub enum Outcome {
    Valid,
    Temp,
}

pub fn validate_message(message: &str, config: &Config) -> Result<Outcome, ValidationError> {
    let parsed = parser::parse(message, config.jira_in_header)?;

    match validate::classify_header(&parsed.header, config)? {
        HeaderKind::Temp => Ok(Outcome::Temp),
        HeaderKind::Revert => {
            validate::revert(&parsed.body, config)?;
            Ok(Outcome::Valid)
        }
        HeaderKind::Conventional {
            type_,
            scope,
            subject,
        } => {
            validate::header_length(&parsed.header, config.header_max_length)?;
            validate::commit_type(&type_)?;
            validate::scope(&scope)?;
            validate::subject(&subject)?;
            validate::body_length(&parsed.body, config.body_max_length)?;
            validate::body_length(&parsed.footer, config.body_max_length)?;
            validate::trailing_space(&parsed.body)?;
            validate::trailing_space(&parsed.footer)?;
            validate::jira(&type_, &parsed.jira, config)?;
            Ok(Outcome::Valid)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn code(msg: &str, config: &Config) -> i32 {
        validate_message(msg, config)
            .map(|_| 0)
            .unwrap_or_else(|e| e.code())
    }

    #[test]
    fn invalid_structure() {
        assert_eq!(code("plop\nplop", &Config::default()), 1);
    }

    #[test]
    fn invalid_header() {
        assert_eq!(code("plop", &Config::default()), 2);
    }

    #[test]
    fn invalid_header_length() {
        let msg = "feat(plop): 012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789";
        assert_eq!(code(msg, &Config::default()), 3);
    }

    #[test]
    fn invalid_type() {
        let msg = "Feat(scope1): subject\n\nCommit about stuff\n\nLUM-2345";
        assert_eq!(code(msg, &Config::default()), 4);
    }

    #[test]
    fn invalid_scope() {
        let msg = "feat(scope 1): subject\n\nCommit about stuff\n\nLUM-2345";
        assert_eq!(code(msg, &Config::default()), 5);
    }

    #[test]
    fn valid_capitalized_subject_is_not_subject_error() {
        let msg = "feat(scope1): Subject\n\nCommit about stuff\n\nLUM-2345";
        assert_ne!(code(msg, &Config::default()), 6);
    }

    #[test]
    fn invalid_body_length() {
        let msg = "feat(scope1): subject\n\n1 2 3 4 5678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901\n\nLUM-2345";
        assert_eq!(code(msg, &Config::default()), 7);
    }

    #[test]
    fn invalid_body_trailing_space() {
        let msg = "chore(scope1): subject\n\n123456789012345678901234567890123456789012 ";
        assert_eq!(code(msg, &Config::default()), 8);
    }

    #[test]
    fn invalid_footer_length() {
        let msg = "feat(scope1): subject\n\nplop\n\nLUM-2345\nBROKEN:\n- 12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901";
        assert_eq!(code(msg, &Config::default()), 7);
    }

    #[test]
    fn invalid_footer_trailing_space() {
        let msg = "feat(scope1): subject\n\nplop\n\nLUM-2345\nBROKEN:\n- 123456 ";
        assert_eq!(code(msg, &Config::default()), 8);
    }

    #[test]
    fn missing_jira() {
        let msg = "feat(scope1): subject\n\nCommit about stuff\n\n2345";
        assert_eq!(code(msg, &Config::default()), 9);
    }

    #[test]
    fn fully_valid() {
        let msg = "feat(scope1): subject\n\nCommit about stuff dezd\n\n12345678901234567890123456789012345678901234567890\n12345678901234567890123456789012345678901234567890\n\nLUM-2345\nBROKEN:\n- plop\n- plop";
        assert_eq!(code(msg, &Config::default()), 0);
    }

    #[test]
    fn revert_valid_with_sha() {
        let msg = "Revert \"feat(scope1): subject\"\n\nThis reverts commit 12345678900.\nCommit about stuff dezd\n\n12345678901234567890123456789012345678901234567890\n\nLUM-2345\nBROKEN:\n- plop\n- plop";
        assert_eq!(code(msg, &Config::default()), 0);
    }

    #[test]
    fn fixup_valid_when_allowed_rejected_otherwise() {
        let msg =
            "fixup! plepozkfopezr\n\nCommit about stuff dezd\n\nLUM-2345\nBROKEN:\n- plop\n- plop";
        let mut c = Config::default();
        assert_eq!(code(msg, &c), 2);
        c.allow_temp = true;
        assert_eq!(code(msg, &c), 0);
    }
}
