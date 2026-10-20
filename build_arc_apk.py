"""Build ARC Signal v4.2 Android APK for Render Python build environment."""
import os
import pathlib
import shutil
import subprocess
import tarfile
import urllib.request
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent
TMP = pathlib.Path('/tmp/arc-v42-build')
TMP.mkdir(parents=True, exist_ok=True)

def download(url, filename):
    target = TMP / filename
    print('Downloading:', url, flush=True)
    urllib.request.urlretrieve(url, target)
    return target

jdk = TMP / 'jdk'
jdk.mkdir(exist_ok=True)
with tarfile.open(download('https://api.adoptium.net/v3/binary/latest/17/ga/linux/x64/jdk/hotspot/normal/eclipse', 'jdk.tar.gz')) as tf:
    tf.extractall(jdk, filter='data')
java_home = next(x for x in jdk.iterdir() if x.is_dir())

sdk = TMP / 'android-sdk'
with zipfile.ZipFile(download('https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip', 'android-tools.zip')) as zf:
    zf.extractall(sdk / 'cmdline-tools')
(sdk / 'cmdline-tools' / 'cmdline-tools').rename(sdk / 'cmdline-tools' / 'latest')

with zipfile.ZipFile(download('https://services.gradle.org/distributions/gradle-8.10.2-bin.zip', 'gradle.zip')) as zf:
    zf.extractall(TMP)

env = dict(os.environ, JAVA_HOME=str(java_home), ANDROID_HOME=str(sdk), ANDROID_SDK_ROOT=str(sdk))
env['PATH'] = ':'.join((str(java_home / 'bin'), str(sdk / 'cmdline-tools' / 'latest' / 'bin'), env['PATH']))
manager = str(sdk / 'cmdline-tools' / 'latest' / 'bin' / 'sdkmanager')
subprocess.run(['bash', '-c', 'yes | sdkmanager --licenses >/dev/null 2>&1 || true'], env=env, check=True)
subprocess.run([manager, 'platform-tools', 'platforms;android-35', 'build-tools;35.0.0'], env=env, check=True)
subprocess.run([str(TMP / 'gradle-8.10.2' / 'bin' / 'gradle'), '--no-daemon', '--console=plain', ':app:assembleDebug'], cwd=ROOT, env=env, check=True)
source = ROOT / 'app/build/outputs/apk/debug/app-debug.apk'
output = ROOT / 'public/ARC_SIGNAL_V4_2.apk'
output.parent.mkdir(exist_ok=True)
shutil.copyfile(source, output)
print('APK created:', output, output.stat().st_size, 'bytes', flush=True)
