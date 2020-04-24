#!/bin/sh
set -e

# Go the sources directory to run commands
SOURCE="${BASH_SOURCE[0]}"
DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
cd $DIR
echo $(pwd)


echo "Generating Static fonts"
rm -rf ../fonts
mkdir -p ../fonts
mkdir -p ../fonts/otf
mkdir -p ../fonts/ttf
mkdir -p ../fonts/variable
fontmake -m Vollkorn.designspace -i -o ttf --output-dir ../fonts/ttf/
fontmake -m Vollkorn-Italic.designspace -i -o ttf --output-dir ../fonts/ttf/

echo "Generating VFs"
fontmake -m Vollkorn.designspace -o variable --output-path ../fonts/variable/Vollkorn[wght].ttf
fontmake -m Vollkorn-Italic.designspace -o variable --output-path ../fonts/variable/Vollkorn-Italic[wght].ttf

rm -rf master_ufo/ instance_ufo/ instance_ufos/

echo "Generate Vollkorn SC VFs"
python3 -m opentype_feature_freezer.cli -S -U SC -f smcp ../fonts/variable/Vollkorn\[wght\].ttf ../fonts/variable/VollkornSC\[wght\].ttf
pyftsubset  --glyph-names --layout-features="*" --name-IDs="*" --unicodes="*" --output-file=../fonts/variable/VollkornSC\[wght\].subset.ttf ../fonts/variable/VollkornSC\[wght\].ttf
mv ../fonts/variable/VollkornSC\[wght\].subset.ttf ../fonts/variable/VollkornSC\[wght\].ttf

echo "Generate Vollkorn SC static fonts"
ttfs=$(ls ../fonts/ttf/*.ttf | grep -v "SC-")
for ttf in $ttfs
do
	scttf=$(echo $ttf | sed 's/-/SC-/');
	subsetscttf=$(basename -s .ttf $scttf).ttf
	python3 -m opentype_feature_freezer.cli -S -U SC -f smcp $ttf $scttf;
	pyftsubset --glyph-names  --layout-features="*" --name-IDs="*" --unicodes="*" --output-file=$subsetscttf $scttf;
	mv $subsetscttf $scttf;
done

echo "Post processing"
ttfs=$(ls ../fonts/ttf/*.ttf)
for ttf in $ttfs
do
	gftools fix-dsig -f $ttf;
	python -m ttfautohint $ttf "$ttf.fix";
	mv "$ttf.fix" $ttf;
done

vfs=$(ls ../fonts/variable/*.ttf)
echo vfs
echo "Post processing VFs"
for vf in $vfs
do
	gftools fix-dsig -f $vf;
	# ./ttfautohint-vf --stem-width-mode nnn $vf "$vf.fix";
	# mv "$vf.fix" $vf;
done

echo "Fixing VF Meta"
gftools fix-vf-meta ../fonts/variable/Vollkorn\[wght\].ttf ../fonts/variable/Vollkorn-Italic\[wght\].ttf;
gftools fix-vf-meta ../fonts/variable/VollkornSC\[wght\].ttf
for vf in $vfs
do
	if [ -f "$vf.fix" ]; then mv "$vf.fix" $vf; fi
done

echo "Dropping MVAR"
for vf in $vfs
do
	ttx -f -x "MVAR" $vf; # Drop MVAR. Table has issue in DW
	rtrip=$(basename -s .ttf $vf)
	new_file=../fonts/variable/$rtrip.ttx;
	rm $vf;
	ttx $new_file
	rm $new_file
done

echo "Fixing Hinting"
for vf in $vfs
do
	gftools fix-nonhinting $vf $vf;
	gftools fix-gasp $vf;
	# gftools fix-hinting $vf;
	if [ -f "$vf.fix" ]; then mv "$vf.fix" $vf; fi
done

for ttf in $ttfs
do
	gftools fix-hinting $ttf;
	gftools fix-gasp $ttf;
	if [ -f "$ttf.fix" ]; then mv "$ttf.fix" $ttf; fi
done

rm -f ../fonts/variable/*.ttx
rm -f ../fonts/ttf/*.ttx
rm -f ../fonts/variable/*gasp.ttf
rm -f ../fonts/ttf/*gasp.ttf

echo "Done"
