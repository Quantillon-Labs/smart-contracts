const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');

const documentedContract = `pragma solidity 0.8.24;
contract Example {
    /**
     * @notice Returns a constant value.
     * @dev Uses no storage or external calls.
     * @return value The constant one.
     * @custom:security No privileged operation.
     * @custom:validation No inputs.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy No external calls.
     * @custom:access Public.
     * @custom:oracle None.
     */
    function value() external pure returns (uint256) { return 1; }
}`;

function validateFixture(t, source) {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'natspec-gate-'));
    t.after(() => fs.rmSync(root, { recursive: true, force: true }));
    fs.mkdirSync(path.join(root, 'scripts'));
    for (const dir of ['src/core', 'src/interfaces', 'src/libraries', 'src/oracle', 'src/core/vaults', 'src/core/yieldmanagement']) {
        fs.mkdirSync(path.join(root, dir), { recursive: true });
    }
    fs.writeFileSync(path.join(root, 'foundry.toml'), '[profile.default]\n');
    fs.writeFileSync(path.join(root, 'src/core/Example.sol'), source);
    fs.copyFileSync(path.join(__dirname, 'validate-natspec.js'), path.join(root, 'scripts/validate-natspec.js'));
    const result = spawnSync(process.execPath, ['scripts/validate-natspec.js'], {
        cwd: root,
        env: { ...process.env, NODE_PATH: path.join(__dirname, 'node_modules'), RESULTS_DIR: 'results' },
        encoding: 'utf8'
    });
    assert.ifError(result.error);
    return result;
}

test('complete production documentation passes', t => {
    const result = validateFixture(t, documentedContract);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stdout, /Overall Coverage: 100\.00%/);
    assert.match(result.stdout, /Parsing Errors: 0/);
});

test('missing required tag fails the gate', t => {
    const result = validateFixture(t, documentedContract.replace('     * @dev Uses no storage or external calls.\n', ''));
    assert.equal(result.status, 1, result.stdout + result.stderr);
    assert.match(result.stdout, /Missing Documentation: 1/);
});

test('parser error cannot pass an incomplete scan', t => {
    const result = validateFixture(t, 'pragma solidity 0.8.24; contract Broken { function oops( }');
    assert.equal(result.status, 1, result.stdout + result.stderr);
    assert.match(result.stdout, /Parsing Errors: 1/);
});

test('zero production functions cannot pass', t => {
    const result = validateFixture(t, 'pragma solidity 0.8.24; contract Empty {}');
    assert.equal(result.status, 1, result.stdout + result.stderr);
    assert.match(result.stdout, /Total Functions: 0/);
});
