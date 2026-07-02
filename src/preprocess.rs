pub enum Preprocessed {
    Skip,
    Message(String),
}

pub fn preprocess_message_file(path: &str, contents: &str) -> Preprocessed {
    if path.ends_with("MERGE_MSG") {
        return Preprocessed::Skip;
    }

    // Remove comment lines (leading '#'), mirroring `sed '/^#/d'`.
    let stripped = contents
        .lines()
        .filter(|line| !line.starts_with('#'))
        .collect::<Vec<_>>()
        .join("\n");

    // First word (up to the first space), lowercased, like `${MSG%% *}`.
    let first_word = stripped.split(' ').next().unwrap_or("").to_lowercase();
    if first_word == "merge" {
        return Preprocessed::Skip;
    }

    // Mirror command substitution's stripping of all trailing newlines.
    Preprocessed::Message(stripped.trim_end_matches('\n').to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn is_skip(path: &str, contents: &str) -> bool {
        matches!(preprocess_message_file(path, contents), Preprocessed::Skip)
    }

    #[test]
    fn skips_merge_msg_path() {
        assert!(is_skip(
            "/some/path/MERGE_MSG",
            "Merge branch 'foo' into 'bar'"
        ));
    }

    #[test]
    fn skips_merge_first_word_any_case() {
        for msg in [
            "Merge branch 'foo' into 'bar'",
            "Merge pull request #1",
            "MERGE branch 'feature' into 'main'",
            "MeRgE branch 'test'",
            "merge whatever",
        ] {
            assert!(is_skip("/x/COMMIT_EDITMSG", msg), "{msg}");
        }
    }

    #[test]
    fn strips_comment_lines() {
        match preprocess_message_file(
            "/x/COMMIT_EDITMSG",
            "# a comment\nfeat(scope): valid subject\n",
        ) {
            Preprocessed::Message(m) => assert_eq!(m, "feat(scope): valid subject"),
            Preprocessed::Skip => panic!("should not skip"),
        }
    }

    #[test]
    fn returns_message_for_normal_commit() {
        match preprocess_message_file("/x/COMMIT_EDITMSG", "feat(widget): add a widget") {
            Preprocessed::Message(m) => assert_eq!(m, "feat(widget): add a widget"),
            Preprocessed::Skip => panic!("should not skip"),
        }
    }

    #[test]
    fn strips_trailing_blank_lines_before_comment_block() {
        // realistic commit-msg file: blank line + comment block get stripped, no trailing newline remains
        match preprocess_message_file(
            "/x/COMMIT_EDITMSG",
            "feat(x): y\n\nbody\n\n# Please enter the commit message\n",
        ) {
            Preprocessed::Message(m) => assert_eq!(m, "feat(x): y\n\nbody"),
            Preprocessed::Skip => panic!("should not skip"),
        }
    }
}
