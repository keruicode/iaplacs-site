const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {execFileSync} = require('node:child_process');

const home = fs.mkdtempSync(path.join(os.tmpdir(), 'iaplacs-ssh-test-'));
const script = path.resolve(__dirname, '../ensure_iaplacs_ssh_state.sh');
const canonical = path.join(home, '.iaplacs/ssh-state');
const ssh = path.join(home, '.ssh');
const managed = 'ssh-rsa TEST_MANAGED_PUBLIC_KEY 2602005529@qq.com\n';
const platform = 'ssh-rsa TEST_PLATFORM_PUBLIC_KEY platform\n';
try {
  fs.mkdirSync(canonical, {recursive:true, mode:0o700});
  fs.mkdirSync(ssh, {mode:0o700});
  for (const name of ['id_rsa', 'id_ed25519_iaplacs_github', 'id_ed25519_iaplacs_github.pub']) {
    fs.writeFileSync(path.join(canonical, name), `TEST_ONLY_${name}\n`, {mode:0o600});
  }
  fs.writeFileSync(path.join(canonical, 'authorized_keys.iaplacs'), managed, {mode:0o600});
  fs.writeFileSync(path.join(ssh, 'authorized_keys'), platform, {mode:0o600});
  fs.writeFileSync(path.join(ssh, 'id_rsa'), 'NEW_PLATFORM_KEY\n', {mode:0o600});
  const run = () => execFileSync('bash', [script], {
    env:{...process.env, HOME:home, IAPLACS_SSH_STATE_DIR:canonical,
      IAPLACS_AUTHORIZED_KEY_COMMENT:'2602005529@qq.com'}, encoding:'utf8',
  });
  const first = run();
  assert(first.includes('restored missing authorized key'));
  assert(first.includes('check complete:'));
  assert.equal(fs.readFileSync(path.join(ssh, 'authorized_keys'), 'utf8'), platform + managed);
  assert.equal(fs.readFileSync(path.join(ssh, 'id_rsa'), 'utf8'), 'NEW_PLATFORM_KEY\n');
  const second = run();
  assert(second.includes('check complete:'));
  assert(!second.includes('restored missing authorized key'));
  assert(!second.includes('TEST_MANAGED_PUBLIC_KEY'));
  assert.equal(fs.readFileSync(path.join(ssh, 'authorized_keys'), 'utf8'), platform + managed);
  fs.rmSync(ssh, {recursive:true});
  assert(run().includes('restored missing authorized key'));
  assert.equal(fs.readFileSync(path.join(ssh, 'authorized_keys'), 'utf8'), managed);
  for (const file of ['id_rsa', 'id_ed25519_iaplacs_github', 'authorized_keys']) {
    assert.equal(fs.statSync(path.join(ssh, file)).mode & 0o777, 0o600);
  }
  console.log('SSH reset recovery, non-overwrite, idempotence and success logging passed.');
} finally {
  fs.rmSync(home, {recursive:true, force:true});
}
