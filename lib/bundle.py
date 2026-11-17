import os
import re
import shutil
import subprocess
import sys

LINUX_SYSTEM = re.compile(
    r"^(linux-vdso|linux-gate|ld-linux|libc|libm|libdl|librt|libpthread|libresolv|libutil|libgcc_s|libstdc\+\+)\.so"
)


def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout


def license_for(source, out):
    dest = os.path.join(out, "licenses")
    if sys.platform == "darwin":
        m = re.match(r"(.*/Cellar/([^/]+)/[^/]+)/", os.path.realpath(source))
        if not m:
            return
        folder, name = m.groups()
        for f in os.listdir(folder):
            if re.match(r"(LICENSE|LICENCE|COPYING|COPYRIGHT|NOTICE)", f, re.I):
                os.makedirs(os.path.join(dest, name), exist_ok=True)
                shutil.copy2(os.path.join(folder, f), os.path.join(dest, name, f))
    else:
        found = subprocess.run(["dpkg", "-S", os.path.realpath(source)], capture_output=True, text=True).stdout
        if not found:
            found = subprocess.run(["dpkg", "-S", source], capture_output=True, text=True).stdout
        if not found:
            return
        package = found.split(":")[0]
        copyright = f"/usr/share/doc/{package}/copyright"
        if os.path.exists(copyright):
            os.makedirs(os.path.join(dest, package), exist_ok=True)
            shutil.copy2(copyright, os.path.join(dest, package, "copyright"))


def is_elf(path):
    with open(path, "rb") as f:
        return f.read(4) == b"\x7fELF"


def is_macho(path):
    with open(path, "rb") as f:
        return f.read(4) in (b"\xcf\xfa\xed\xfe", b"\xca\xfe\xba\xbe")


def files(out, check):
    found = []
    for sub in ("bin", "lib"):
        for root, _, names in os.walk(os.path.join(out, sub)):
            for name in names:
                path = os.path.join(root, name)
                if os.path.isfile(path) and not os.path.islink(path) and check(path):
                    found.append(path)
    return found


def linux(out):
    lib = os.path.join(out, "lib")
    pending = files(out, is_elf)
    seen = set(pending)
    while pending:
        path = pending.pop()
        for line in run("ldd", path).splitlines():
            m = re.match(r"\s*(\S+) => (\S+)", line)
            if not m:
                continue
            name, resolved = m.groups()
            if resolved == "not":
                sys.exit(f"bundle: {path} needs {name}, which isn't installed")
            if LINUX_SYSTEM.match(name) or resolved.startswith(out + "/"):
                continue
            dest = os.path.join(lib, name)
            if not os.path.exists(dest):
                shutil.copy2(resolved, dest)
                os.chmod(dest, 0o755)
                license_for(resolved, out)
            if dest not in seen:
                seen.add(dest)
                pending.append(dest)
    for path in files(out, is_elf):
        rel = os.path.relpath(lib, os.path.dirname(path))
        rpath = "$ORIGIN" if rel == "." else f"$ORIGIN/{rel}"
        run("patchelf", "--set-rpath", rpath, path)


def macos_deps(path):
    lines = run("otool", "-L", path).splitlines()[1:]
    own = run("otool", "-D", path).splitlines()[1:]
    return [l.split()[0] for l in lines if l.split()[0] not in own]


def resolve_rpath(path, origin_dir, rest, lib):
    candidates = [os.path.join(lib, rest), os.path.join(origin_dir, rest)]
    lines = run("otool", "-l", path).splitlines()
    for i, line in enumerate(lines):
        if line.strip() == "cmd LC_RPATH":
            rpath = lines[i + 2].split()[1]
            rpath = rpath.replace("@loader_path", origin_dir).replace("@executable_path", origin_dir)
            candidates.append(os.path.normpath(os.path.join(rpath, rest)))
    for candidate in candidates:
        if os.path.exists(candidate):
            return candidate
    sys.exit(f"bundle: can't resolve @rpath/{rest} in {path}")


def macos(out):
    lib = os.path.join(out, "lib")
    origin = {}
    pending = files(out, is_macho)
    for path in pending:
        origin[path] = os.path.dirname(path)
    done = set()
    while pending:
        path = pending.pop()
        if path in done:
            continue
        done.add(path)
        os.chmod(path, 0o755)
        for dep in macos_deps(path):
            if dep.startswith(("/usr/lib/", "/System/")):
                continue
            name = os.path.basename(dep)
            if dep.startswith("@loader_path/"):
                source = os.path.normpath(os.path.join(origin[path], dep[len("@loader_path/"):]))
            elif dep.startswith("@rpath/"):
                source = resolve_rpath(path, origin[path], dep[len("@rpath/"):], lib)
            else:
                source = dep
            dest = os.path.join(lib, name)
            if not os.path.exists(dest):
                shutil.copy2(source, dest)
                os.chmod(dest, 0o755)
                origin[dest] = os.path.dirname(source)
                pending.append(dest)
                license_for(source, out)
            run("install_name_tool", "-change", dep, f"@rpath/{name}", path)
        if path.endswith(".dylib") and os.path.dirname(path) == lib:
            run("install_name_tool", "-id", f"@rpath/{os.path.basename(path)}", path)
        rel = os.path.relpath(lib, os.path.dirname(path))
        anchor = "@executable_path" if path.startswith(os.path.join(out, "bin") + "/") else "@loader_path"
        rpath = anchor if rel == "." else f"{anchor}/{rel}"
        uses_rpath = any(d.startswith("@rpath/") for d in macos_deps(path))
        if uses_rpath and rpath not in run("otool", "-l", path):
            subprocess.run(["install_name_tool", "-add_rpath", rpath, path], check=True, capture_output=True)
    for path in files(out, is_macho):
        run("codesign", "--force", "--sign", "-", path)


if __name__ == "__main__":
    out = os.path.abspath(sys.argv[1])
    (macos if sys.platform == "darwin" else linux)(out)
