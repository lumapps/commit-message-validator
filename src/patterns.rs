use regex::Regex;
use std::sync::LazyLock;

pub const JIRA: &str = r"[A-Z]{2,7}[0-9]{0,6}-[0-9]{1,6}";

pub static HEADER: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"^([^(]+)\(([^)]+)\): (.+)$").unwrap());
pub static TYPE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"^(feat|fix|docs|gen|lint|refactor|test|chore)$").unwrap());
pub static SCOPE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"^([a-z][a-z0-9]*)(-[a-z0-9]+)*$").unwrap());
pub static SUBJECT: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"^[A-Za-z0-9].*[^ ^.]$").unwrap());
pub static JIRA_FOOTER: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(&format!(r"^({JIRA} ?)+$")).unwrap());
pub static JIRA_HEADER: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(&format!(r"^.*[^A-Z]({JIRA}).*$")).unwrap());
pub static BROKE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"^BROKEN:$").unwrap());
pub static TRAILING_SPACE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r" +$").unwrap());
pub static REVERT_HEADER: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"^[Rr](evert|eapply)[: ].*$").unwrap());
pub static REVERT_COMMIT: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"^This reverts commit ([a-f0-9]+)").unwrap());
pub static TEMP_HEADER: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"^(fixup!|squash!).*$").unwrap());

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn header_captures_type_scope_subject() {
        let caps = HEADER.captures("type(scope): message").unwrap();
        assert_eq!(&caps[1], "type");
        assert_eq!(&caps[2], "scope");
        assert_eq!(&caps[3], "message");
    }

    #[test]
    fn header_rejects_malformed() {
        assert!(HEADER.captures("type(scope):message").is_none());
        assert!(HEADER.captures("type scope: message").is_none());
        assert!(HEADER.captures("type(scope): ").is_none());
    }

    #[test]
    fn type_only_known_lowercase() {
        assert!(TYPE.is_match("feat"));
        assert!(!TYPE.is_match("Feat"));
        assert!(!TYPE.is_match("feat "));
        assert!(!TYPE.is_match("plop"));
    }

    #[test]
    fn scope_is_kebab_case() {
        assert!(SCOPE.is_match("p2"));
        assert!(SCOPE.is_match("pl2op-plop1-plop-0001"));
        assert!(!SCOPE.is_match(""));
        assert!(!SCOPE.is_match("plopPlop"));
        assert!(!SCOPE.is_match("plop plop"));
        assert!(!SCOPE.is_match("plop "));
    }

    #[test]
    fn subject_rules() {
        assert!(SUBJECT.is_match("0002 dedezf ef"));
        assert!(!SUBJECT.is_match(""));
        assert!(!SUBJECT.is_match("plop "));
        assert!(!SUBJECT.is_match("plop."));
    }

    #[test]
    fn jira_footer_and_header() {
        assert!(JIRA_FOOTER.is_match("ABC-1234"));
        assert!(JIRA_FOOTER.is_match("ABC-1234 DE-1234"));
        assert!(!JIRA_FOOTER.is_match("2345"));
        let caps = JIRA_HEADER.captures("feat(abc): ABC-1234").unwrap();
        assert_eq!(&caps[1], "ABC-1234");
    }

    #[test]
    fn misc_patterns() {
        assert!(BROKE.is_match("BROKEN:"));
        assert!(TRAILING_SPACE.is_match("foo "));
        assert!(!TRAILING_SPACE.is_match("foo"));
        assert!(REVERT_HEADER.is_match("revert: type(scope): message"));
        assert!(REVERT_HEADER.is_match("Revert \"type(scope): message\""));
        assert!(REVERT_COMMIT
            .captures("This reverts commit 1234abcd.")
            .is_some());
        assert!(TEMP_HEADER.is_match("fixup! foo"));
        assert!(TEMP_HEADER.is_match("squash! foo"));
    }
}
