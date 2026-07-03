use std::fmt;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ValidationError {
    Structure(String),
    Header(String),
    HeaderLength(String),
    Type(String),
    Scope(String),
    Subject(String),
    BodyLength(String),
    TrailingSpace(String),
    Jira(String),
    Revert(String),
}

impl ValidationError {
    pub fn code(&self) -> i32 {
        match self {
            ValidationError::Structure(_) => 1,
            ValidationError::Header(_) => 2,
            ValidationError::HeaderLength(_) => 3,
            ValidationError::Type(_) => 4,
            ValidationError::Scope(_) => 5,
            ValidationError::Subject(_) => 6,
            ValidationError::BodyLength(_) => 7,
            ValidationError::TrailingSpace(_) => 8,
            ValidationError::Jira(_) => 9,
            ValidationError::Revert(_) => 10,
        }
    }

    fn message(&self) -> &str {
        match self {
            ValidationError::Structure(m)
            | ValidationError::Header(m)
            | ValidationError::HeaderLength(m)
            | ValidationError::Type(m)
            | ValidationError::Scope(m)
            | ValidationError::Subject(m)
            | ValidationError::BodyLength(m)
            | ValidationError::TrailingSpace(m)
            | ValidationError::Jira(m)
            | ValidationError::Revert(m) => m,
        }
    }
}

impl fmt::Display for ValidationError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.message())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn codes_match_historical_values() {
        assert_eq!(ValidationError::Structure(String::new()).code(), 1);
        assert_eq!(ValidationError::Header(String::new()).code(), 2);
        assert_eq!(ValidationError::HeaderLength(String::new()).code(), 3);
        assert_eq!(ValidationError::Type(String::new()).code(), 4);
        assert_eq!(ValidationError::Scope(String::new()).code(), 5);
        assert_eq!(ValidationError::Subject(String::new()).code(), 6);
        assert_eq!(ValidationError::BodyLength(String::new()).code(), 7);
        assert_eq!(ValidationError::TrailingSpace(String::new()).code(), 8);
        assert_eq!(ValidationError::Jira(String::new()).code(), 9);
        assert_eq!(ValidationError::Revert(String::new()).code(), 10);
    }

    #[test]
    fn display_renders_message() {
        assert_eq!(ValidationError::Type("boom".into()).to_string(), "boom");
    }
}
