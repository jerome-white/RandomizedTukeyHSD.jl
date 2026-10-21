#!/bin/sh
# Computes the p-values of Sakai's own randomised Tukey HSD code (Discpower)
# for a tidy CSV (topic,system,score), writing system1,system2,difference,p.
#
#   sh sakai_reference.sh ../data/ties.csv > ../data/ties_sakai.csv
#
# Instead of random permutations, Sakai's C program permmat2maxmin is fed
# every within-topic arrangement, so the p-values are exact and need no
# Monte Carlo tolerance. The counting rule is the one in his Random-test
# script (`$4 >= diff { count++ }`, with the system means printed by awk).
# His shuffling is not exercised.
#
# Needs curl, tar, make, a C compiler, awk and Julia (set JULIA to override).
# Discpower is downloaded and built in a temporary directory; its source is
# not redistributed here because it carries no licence.

set -eu

URL=http://research.nii.ac.jp/ntcir/tools/Discpower160507.tar.gz
SHA256=97e47803a934ce86bb8fafc5094224c8dc8527f80e7b80fad6e97be6ec5fdd18

HERE=$(cd "$(dirname "$0")" && pwd)
JULIA=${JULIA:-julia}
CSV=$1

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# fetch and build; the 2011 K&R main() needs C89 mode with current compilers
curl -sSL -o "$WORK/discpower.tar.gz" "$URL"
echo "$SHA256  $WORK/discpower.tar.gz" | shasum -a 256 -c - >&2
(
    cd "$WORK"
    tar -xzf discpower.tar.gz
    rm -f permmat2maxmin
    sed -i.bak 's/^CC   =gcc /CC   =gcc -std=gnu89 -w /' Makefile
    make >&2
)

# topic-by-system matrix and system names, in order of first appearance
awk -F, 'NR > 1 {
    if (!($1 in r)) r[$1] = ++nr
    if (!($2 in c)) { c[$2] = ++nc; name[nc] = $2 }
    m[r[$1], c[$2]] = $3
}
END {
    for (i = 1; i <= nr; i++) {
        line = ""
        for (j = 1; j <= nc; j++) line = line (j > 1 ? " " : "") m[i, j]
        print line
    }
    for (j = 1; j <= nc; j++) print name[j] > "'"$WORK"'/names"
}' "$CSV" > "$WORK/matrix"

NTOPICS=$(wc -l < "$WORK/matrix" | tr -d ' ')
NSYSTEMS=$(wc -l < "$WORK/names" | tr -d ' ')

B=$("$JULIA" --project="$HERE/../.." "$HERE/arrangements.jl" \
     "$CSV" "$WORK/arrangements")

"$WORK/permmat2maxmin" "$NSYSTEMS" "$NTOPICS" "$B" "$WORK/arrangements" \
    > "$WORK/maxmin"

# original system means, printed by awk as in Random-test
awk '{ for (i = 1; i <= NF; i++) sum[i] += $i }
     END { for (i = 1; i <= NF; i++) print i, sum[i] / NR }' \
    "$WORK/matrix" > "$WORK/means"

echo "system1,system2,difference,p"
i=1
while [ "$i" -le "$NSYSTEMS" ]; do
    j=$((i + 1))
    while [ "$j" -le "$NSYSTEMS" ]; do
        M1=$(awk -v k="$i" '$1 == k { print $2; exit }' "$WORK/means")
        M2=$(awk -v k="$j" '$1 == k { print $2; exit }' "$WORK/means")
        N1=$(sed -n "${i}p" "$WORK/names")
        N2=$(sed -n "${j}p" "$WORK/names")
        awk "BEGIN { diff = $M1 - $M2; if (diff < 0) { diff *= -1 } }
             \$4 >= diff { count++ }
             END { print \"$N1,$N2,\" diff \",\" count / NR }" \
            "$WORK/maxmin"
        j=$((j + 1))
    done
    i=$((i + 1))
done
