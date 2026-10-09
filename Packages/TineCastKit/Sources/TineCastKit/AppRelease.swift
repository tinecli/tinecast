import Foundation

public func releaseVersion(fromLocation location: String) -> String? {
    guard let tag = location.split(separator: "/").last else { return nil }
    let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : String(tag)
    guard !version.isEmpty, version.allSatisfy({ ($0.isASCII && $0.isNumber) || $0 == "." }) else { return nil }
    return version
}

public func isNewerVersion(_ remote: String, than local: String) -> Bool {
    let components = { (version: String) in
        (version.hasPrefix("v") ? String(version.dropFirst()) : version).split(separator: ".").map { Int($0) ?? 0 }
    }
    let r = components(remote), l = components(local)
    for index in 0..<max(r.count, l.count) {
        let a = index < r.count ? r[index] : 0, b = index < l.count ? l[index] : 0
        if a != b { return a > b }
    }
    return false
}

// Paths only ever arrive as arguments; interpolating one into this script would make it shell-injectable.
public let updateSwapScript = """
#!/bin/sh
set -u
[ "$(id -u)" = "0" ] && exit 1
pid=$1; staged=$2; target=$3; relaunch=$4; expected=$5
i=0
while kill -0 "$pid" 2>/dev/null && [ "$i" -lt 300 ]; do sleep 0.2; i=$((i+1)); done
kill -0 "$pid" 2>/dev/null && exit 1
[ -d "$staged" ] && [ -d "$target" ] || exit 1
now=$(/usr/bin/plutil -extract CFBundleShortVersionString raw -o - "$target/Contents/Info.plist" 2>/dev/null)
[ "$now" = "$expected" ] || exit 1
backup="$target.tinecast-old"
rm -rf "$backup"
mv "$target" "$backup" || exit 1
if ! mv "$staged" "$target"; then
  mv "$backup" "$target"
  exit 1
fi
rm -rf "$backup"
rm -rf "$(dirname "$staged")"
if [ "$relaunch" = "open" ]; then open "$target"; fi
rm -f "$0"
exit 0
"""
