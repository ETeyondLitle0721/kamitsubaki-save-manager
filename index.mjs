#!/usr/bin/env node
// index.mjs
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import fs from 'node:fs';
import readline from 'node:readline/promises';
import { stdin as input, stdout as output } from 'node:process';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PS_SCRIPT = path.join(__dirname, 'registry-ops.ps1');
const BACKUP_DIR = path.join(__dirname, 'backups');

// ⬇️ 在这里统一定义注册表路径，传递给 PowerShell
const REGISTRY_PATH = 'HKCU:\\Software\\株式会社THINKR\\Kamitsubaki City Under Construction REGENERATE';
const NATIVE_PATH = 'HKEY_CURRENT_USER\\Software\\株式会社THINKR\\Kamitsubaki City Under Construction REGENERATE';
// ⬆️ ----------------------------------------

// ---------- PowerShell 调用封装 ----------
function runPwsh(action, extraArgs = {}) {
    return new Promise((resolve) => {
        const args = [
            '-NoProfile',
            '-NonInteractive',
            '-ExecutionPolicy', 'Bypass',
            '-File', PS_SCRIPT,
            '-Action', action,
            '-RegistryPath', REGISTRY_PATH, // 传入路径
            '-NativePath', NATIVE_PATH,     // 传入原生路径
        ];
        if (extraArgs.BackupDir) args.push('-BackupDir', extraArgs.BackupDir);
        if (extraArgs.BackupPath) args.push('-BackupPath', extraArgs.BackupPath);

        const child = spawn('pwsh.exe', args, {
            stdio: ['ignore', 'pipe', 'pipe'],
            windowsHide: true,
        });

        let stdout = '';
        let stderr = '';

        child.stdout.on('data', (chunk) => { stdout += chunk.toString('utf8'); });
        child.stderr.on('data', (chunk) => { stderr += chunk.toString('utf8'); });

        child.on('close', (code) => {
            if (code !== 0) {
                resolve({ ok: false, error: `pwsh 退出码 ${code}：${stderr.trim() || stdout.trim()}` });
                return;
            }
            const lines = stdout.trim().split(/\r?\n/).filter(Boolean);
            for (let i = lines.length - 1; i >= 0; i--) {
                try {
                    resolve(JSON.parse(lines[i]));
                    return;
                } catch { /* 继续向上找 */ }
            }
            resolve({ ok: false, error: '无法解析 PowerShell 输出', raw: stdout });
        });
    });
}

// ---------- 工具函数 ----------
function formatSize(bytes) {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / 1024 / 1024).toFixed(2)} MB`;
}

function printHeader() {
    console.log('\n══════════════════════════════════════════');
    console.log('  Kamitsubaki City Under Construction');
    console.log('  REGENERATE 存档管理工具');
    console.log('══════════════════════════════════════════');
}

function printMenu() {
    console.log('\n  1. 备份当前存档');
    console.log('  2. 从备份恢复');
    console.log('  3. 清空当前存档');
    console.log('  4. 检查注册表状态');
    console.log('  0. 退出\n');
}

// ---------- 业务逻辑 ----------
async function ensureBackupDir() {
    if (!fs.existsSync(BACKUP_DIR)) {
        fs.mkdirSync(BACKUP_DIR, { recursive: true });
    }
}

async function doBackup() {
    console.log('\n⏳ 正在备份...');
    const result = await runPwsh('Backup', { BackupDir: BACKUP_DIR });
    if (!result.ok) {
        console.log(`❌ 备份失败：${result.error}`);
        return;
    }
    console.log(`✅ 备份成功：${result.file}`);
    console.log(`   时间：${result.time}`);
    console.log(`   路径：${result.fullPath}`);
}

async function doRestore(rl) {
    const listResult = await runPwsh('ListBackups', { BackupDir: BACKUP_DIR });
    if (!listResult.ok) {
        console.log(`❌ 读取备份列表失败：${listResult.error}`);
        return;
    }
    const backups = listResult.backups || [];
    if (backups.length === 0) {
        console.log('\n📭 暂无备份文件。');
        return;
    }

    console.log('\n📦 可用备份：\n');
    backups.forEach((b, i) => {
        console.log(`  ${String(i + 1).padStart(2)}. ${b.name}`);
        console.log(`      时间：${b.time}  大小：${formatSize(b.size)}\n`);
    });

    const answer = await rl.question('请选择要恢复的备份编号（直接回车取消）：');
    const idx = Number(answer.trim()) - 1;
    if (!Number.isInteger(idx) || idx < 0 || idx >= backups.length) {
        console.log('↩️  已取消。');
        return;
    }

    const chosen = backups[idx];
    console.log(`\n⚠️  即将恢复备份：${chosen.name}`);
    console.log('   恢复前会先清空当前存档，确定继续？');
    const confirm = await rl.question('   输入 yes 确认：');
    if (confirm.trim().toLowerCase() !== 'yes') {
        console.log('↩️  已取消。');
        return;
    }

    console.log('\n⏳ 正在恢复...');
    const result = await runPwsh('Restore', {
        BackupDir: BACKUP_DIR,
        BackupPath: chosen.path,
    });
    if (!result.ok) {
        console.log(`❌ 恢复失败：${result.error}`);
        return;
    }
    console.log(`✅ 恢复成功：${result.file}`);
}

async function doClear(rl) {
    const check = await runPwsh('Check');
    if (!check.ok) {
        console.log(`❌ 检查注册表失败：${check.error}`);
        return;
    }
    if (!check.exists) {
        console.log('\nℹ️  当前注册表路径不存在，已经是空状态。');
        return;
    }

    console.log('\n⚠️  即将清空当前存档（删除整个注册表路径及其子项）。');
    console.log('   建议先执行备份。确定继续？');
    const confirm = await rl.question('   输入 yes 确认：');
    if (confirm.trim().toLowerCase() !== 'yes') {
        console.log('↩️  已取消。');
        return;
    }

    console.log('\n⏳ 正在清空...');
    const result = await runPwsh('Clear');
    if (!result.ok) {
        console.log(`❌ 清空失败：${result.error}`);
        return;
    }
    if (result.alreadyEmpty) {
        console.log('ℹ️  当前已经是空状态，无需清空。');
    } else {
        console.log('✅ 存档已清空。');
    }
}

async function doCheck() {
    const result = await runPwsh('Check');
    if (!result.ok) {
        console.log(`❌ 检查失败：${result.error}`);
        return;
    }
    console.log(`\n注册表路径：${result.registryPath}`);
    console.log(`是否存在：${result.exists ? '✅ 是' : '❌ 否'}`);
}

// ---------- 主入口 ----------
async function main() {
    if (process.platform !== 'win32') {
        console.error('此工具仅支持 Windows。');
        process.exit(1);
    }
    if (!fs.existsSync(PS_SCRIPT)) {
        console.error(`找不到 PowerShell 脚本：${PS_SCRIPT}`);
        process.exit(1);
    }

    await ensureBackupDir();
    const rl = readline.createInterface({ input, output });

    try {
        printHeader();
        while (true) {
            printMenu();
            const choice = (await rl.question('请输入选项：')).trim();

            switch (choice) {
                case '1': await doBackup(); break;
                case '2': await doRestore(rl); break;
                case '3': await doClear(rl); break;
                case '4': await doCheck(); break;
                case '0':
                    console.log('\n👋 再见。\n');
                    return;
                default:
                    console.log('⚠️  无效选项，请重新输入。');
            }
        }
    } finally {
        rl.close();
    }
}

main().catch((err) => {
    console.error('未处理的错误：', err);
    process.exit(1);
});