/**
 * Action script executed for commit-message-validation
 *
 * Inspired by https://github.com/wagoid/commitlint-github-action  (MIT license)
 *
 * */

const core = require('@actions/core');
const github = require('@actions/github');
const {exec, execFile} = require('child_process');


const PULL_REQUEST = "pull_request";
const PUSH = "push";
const DEFAULT_SHA = '0000000000000000000000000000000000000000'


/***
 * Gets the before sha from github context if there is one, else null
 * @returns {string}
 */
function getBeforePush() {
    if (github.context.payload.forced) {
        // When a commit is forced, "before" field from the push event data may point to a commit that doesn't exist
        return "origin"
    }
    return github.context.payload.before === DEFAULT_SHA ? "origin" : github.context.payload.before;
}

/***
 * Executes the commit message validator script over a commit message
 * @param {string} message The commit message to validate
 * @returns {Promise<void>}
 */
function validatorAsync(message) {
    return new Promise((resolve, reject) => {
        execFile(`./validator.sh`, [message], (error, stdout, stderr) => {
            if (error) {
                console.error(stderr);
                reject(error);
            }
            console.log(stdout);
            resolve()
        });
    })
}


/***
 * Returns git hash and messages for a range
 * @param {string} range
 * @returns {Promise<{message: string, hash: string}[]>}
 */
function getCommitMessages(range) {
    return new Promise((resolve, reject) => {
        const commitDelimiter = '--------->commit---------'
        const hashDelimiter = '--------->hash---------'
        const pretty = `--pretty="%H${hashDelimiter}%B%n${commitDelimiter}"`
        let options = [pretty, '--no-merges', '--no-decorate']
        if (range)
            options.push(range)
        const args = options.join(' ')

        exec(`git log ${args}`, ((error, stdout, stderr) => {
            if (error) {
                reject(error);
            }

            const commits = stdout.split(`${commitDelimiter}\n`).map(messageItem => {
                const [hash, message] = messageItem.split(hashDelimiter)
                return hash ? {
                    hash,
                    message,
                } : null;
            })

            resolve(commits)
        }))
    })

}

async function chek_commits(from, to) {
    const range = [from, to].filter(Boolean).join('..')

    console.log(`Validating commit range: ${range}`);

    const messages = await getCommitMessages(range);

    if (messages.length === 0)
        throw new Error("No Commit found!");

    for (const {hash, message} of messages) {
        console.log(`Validating commit: ${hash}`)
        await validatorAsync(message)
    }
}

/***
 * Validates PR commits for current PR by getting commit list from github API
 * @returns {Promise<void>}
 */
async function pull_request_handler() {

    console.log(`Validating pull request event`);

    const from = `origin/${github.context.payload.pull_request.base.ref}`
    const to = `origin/${github.context.payload.pull_request.head.ref}`

    await getCommitMessages().then(console.log)
    return

    await chek_commits(from, to);

}

/***
 * Gets commit range from push event
 * @returns {Promise<void>}
 */
async function push_handler() {
    console.log(`Validating push event`);

    console.log(github.context.payload)

    const commits = github.context.payload.commits
    if (commits.length === 0) {
        console.log(`Pushing tag(s), ignoring validation.`);
        return
    }

    console.log(`Validating ${commits.length} commit(s)`);

    await getCommitMessages().then(console.log)
    return


    const from = github.context.payload.before
    const to = github.context.payload.after

    await chek_commits(from, to);


}

(async () => {
    process.env['COMMIT_VALIDATOR_NO_JIRA'] = core.getInput("no_jira")
    process.env['COMMIT_VALIDATOR_ALLOW_TEMP'] = core.getInput("allow_temp")
    const eventName = github.context.eventName;
    if (eventName === PULL_REQUEST)
        await pull_request_handler();
    else if (eventName === PUSH)
        await push_handler()
    else
        throw new Error(`Event not handled ${eventName}`);
})().catch(core.setFailed);

module.exports = {
    gitCommits: getCommitMessages
}
