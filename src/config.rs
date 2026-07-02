#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Config {
    pub no_jira: bool,
    pub allow_temp: bool,
    pub no_revert_sha1: bool,
    pub jira_in_header: bool,
    pub header_max_length: usize,
    pub body_max_length: usize,
    pub jira_types: Vec<String>,
}

impl Default for Config {
    fn default() -> Self {
        Config {
            no_jira: false,
            allow_temp: false,
            no_revert_sha1: false,
            jira_in_header: false,
            header_max_length: 100,
            body_max_length: 100,
            jira_types: vec!["feat".to_string(), "fix".to_string()],
        }
    }
}

#[derive(Debug, Default)]
pub struct Overrides {
    pub no_jira: bool,
    pub allow_temp: bool,
    pub no_revert_sha1: bool,
    pub jira_in_header: bool,
    pub header_length: Option<usize>,
    pub body_length: Option<usize>,
    pub jira_types: Option<String>,
}

fn resolve_usize(cli: Option<usize>, env: Option<String>, default: usize) -> usize {
    if let Some(n) = cli {
        return n;
    }
    env.and_then(|v| v.parse().ok()).unwrap_or(default)
}

impl Config {
    pub fn resolve(o: &Overrides, env: impl Fn(&str) -> Option<String>) -> Config {
        let flag = |cli: bool, name: &str| cli || env(name).is_some_and(|v| !v.is_empty());
        let default = Config::default();
        let jira_types = o
            .jira_types
            .clone()
            .or_else(|| env("GLOBAL_JIRA_TYPES").filter(|v| !v.is_empty()))
            .map(|t| t.split_whitespace().map(String::from).collect())
            .unwrap_or(default.jira_types);
        Config {
            no_jira: flag(o.no_jira, "COMMIT_VALIDATOR_NO_JIRA"),
            allow_temp: flag(o.allow_temp, "COMMIT_VALIDATOR_ALLOW_TEMP"),
            no_revert_sha1: flag(o.no_revert_sha1, "COMMIT_VALIDATOR_NO_REVERT_SHA1"),
            jira_in_header: flag(o.jira_in_header, "GLOBAL_JIRA_IN_HEADER"),
            header_max_length: resolve_usize(
                o.header_length,
                env("GLOBAL_MAX_LENGTH"),
                default.header_max_length,
            ),
            body_max_length: resolve_usize(
                o.body_length,
                env("GLOBAL_BODY_MAX_LENGTH"),
                default.body_max_length,
            ),
            jira_types,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn no_env(_: &str) -> Option<String> {
        None
    }

    #[test]
    fn defaults_when_nothing_set() {
        let c = Config::resolve(&Overrides::default(), no_env);
        assert!(!c.no_jira && !c.allow_temp && !c.no_revert_sha1 && !c.jira_in_header);
        assert_eq!(c.header_max_length, 100);
        assert_eq!(c.body_max_length, 100);
        assert_eq!(c.jira_types, vec!["feat".to_string(), "fix".to_string()]);
    }

    #[test]
    fn cli_flag_enables_bool() {
        let o = Overrides {
            no_jira: true,
            ..Default::default()
        };
        assert!(Config::resolve(&o, no_env).no_jira);
    }

    #[test]
    fn nonempty_env_enables_bool_empty_does_not() {
        let on = |n: &str| (n == "COMMIT_VALIDATOR_NO_JIRA").then(|| "1".to_string());
        let empty = |n: &str| (n == "COMMIT_VALIDATOR_NO_JIRA").then(String::new);
        assert!(Config::resolve(&Overrides::default(), on).no_jira);
        assert!(!Config::resolve(&Overrides::default(), empty).no_jira);
    }

    #[test]
    fn cli_length_overrides_env_and_default() {
        let o = Overrides {
            header_length: Some(150),
            ..Default::default()
        };
        assert_eq!(Config::resolve(&o, no_env).header_max_length, 150);
    }

    #[test]
    fn env_length_used_when_no_cli_and_empty_falls_back() {
        let set = |n: &str| (n == "GLOBAL_BODY_MAX_LENGTH").then(|| "150".to_string());
        let empty = |n: &str| (n == "GLOBAL_BODY_MAX_LENGTH").then(String::new);
        assert_eq!(
            Config::resolve(&Overrides::default(), set).body_max_length,
            150
        );
        assert_eq!(
            Config::resolve(&Overrides::default(), empty).body_max_length,
            100
        );
    }

    #[test]
    fn jira_types_split_on_whitespace() {
        let o = Overrides {
            jira_types: Some("feat fix chore".into()),
            ..Default::default()
        };
        let c = Config::resolve(&o, no_env);
        assert_eq!(c.jira_types, vec!["feat", "fix", "chore"]);
    }

    #[test]
    fn empty_env_jira_types_falls_back_to_default() {
        let empty = |n: &str| (n == "GLOBAL_JIRA_TYPES").then(String::new);
        assert_eq!(
            Config::resolve(&Overrides::default(), empty).jira_types,
            vec!["feat".to_string(), "fix".to_string()]
        );
    }
}
