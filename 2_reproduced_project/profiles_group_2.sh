group=2

## BEFORE RUNNING, CHECK SNSCRAPE OUTPUT TO DETERMINE IF THE CONTENT FIELD IS rawDescription OR Description 


profiles () {

# only those users that have descriptions; the N of users will be less than in the main MD analysis (= user_index.txt)

echo "--- profiles ... ---"

mkdir -p profiles

# grabbing usernames and their profile descriptions, and numbering the users according to
# the same scheme used for the main MD analysis (user_index.txt)

grep -E '^    "username":|^    "rawDescription":' tweets/jq.txt > a
tr '~' ' ' < a | tr '|' ' ' | sed 's/    "username/~"username/' | tr '\n' ' ' | tr '~' '\n' > b
sort b | uniq | grep '^"username":' | sed 's/"rawDescription": "",/"rawDescription": null,/' | tr -s ' ' | sed -e 's/"username": "/u:/' -e 's/", "rawDescription": "/|c:/' -e 's/", $//' -e 's;\\n; ;g'  | grep -v ' "rawDescription": null' | tr '\t' ' ' | tr -s ' ' > c
cut -d'|' -f1 c | tr '[:upper:]' '[:lower:]' > d
cut -d'|' -f2- c | tr '\t' ' ' | tr -s ' ' > e
paste d e | tr '\t' '|' > f
sort -t'|' -k1,1 f | sed 's/:/|/' > g
tr ' ' '|' < user_index.txt | sort -t'|' -k2,2 > i
join -t'|' -1 2 -2 2 -o 2.1 -o 1.1 -o 1.2 -o 1.3 g i | sed 's/|u|/|u:/' > profiles/profiles.txt

}

tokenizing () {

last=$( cat profiles/profiles.txt | wc -l | tr -dc '[0-9]' )

rm -f profiles/tokenized.txt  ### WATCH THIS!

for i in $(eval echo {1..$last});
do
  echo "--- tokenizing $i / $last ---"
  sed -n "$i"p profiles/profiles.txt | tr '|' '\n' | grep -v '^c:' > a
  sed -n "$i"p profiles/profiles.txt | tr '|' '\n' | grep '^c:' | sed 's/^c://' | gsed -e "s/\([.\!?,'/()]\)/ \1 /g" -e 's/\#/ \#/g' | tr -s ' ' | sed 's/^/c:/' >> a
  tr '\n' '|' < a | sed 's/~$//' >> profiles/tokenized.txt
  echo >> profiles/tokenized.txt 
done

}

emoji () {

# speed: 1000 tweets = 100 seconds 

# converting emojis to words; words in the emoji label are marked with _e

last=$( cat profiles/tokenized.txt | wc -l | tr -dc '[0-9]' )

rm -f profiles/emoji.txt  ### WATCH THIS!

for i in $(eval echo {1..$last});
#for i in {1..20}
do
  echo "--- demoji $i / $last ---"
  sed -n "$i"p profiles/tokenized.txt | tr '|' '\n' | grep -v '^c:' | grep -v '^$' > a
  sed -n "$i"p profiles/tokenized.txt | sed -e 's/</LESSTHANSIGN/g' -e 's/>/GREATERTHANSIGN/g' | tr '|' '\n' | grep '^c:' | sed -e 's/c://' | demoji | sed -e 's/</~</g' -e 's/>/>~/g' -e 's/#/~#/g' | tr '~' '\n' | tr -s ' ' | sed -e '/^</s/://g' -e '/^</s/ /_/g' | gsed -e 's/^<\(.*\)>$/EMOJI_\L\1_e/' | tr ' ' '\n' | gsed -e '/^#/s/\(.*\)/HASHTAG\L\1_h/' -e '/EMOJI/s/[[:punct:]]/_/g' | tr -s '_ ' | grep -v '^$' | tr '\n' ' ' | sed -e 's/LESSTHANSIGN/</g' -e 's/GREATERTHANSIGN/>/g' | sed 's/^/c:/' >> a
  tr '\n' '|' < a | sed 's/~$//' >> profiles/emoji.txt
  echo >> profiles/emoji.txt 
done 

}

treetagging () {

# speed: 150 lines = 14 sec

last=$( cat profiles/emoji.txt | wc -l | tr -dc '[0-9]' )

rm -f profiles/tagged.txt  ### WATCH THIS!

for i in $(eval echo {1..$last});
#for i in {1..30};
do
  echo "--- treetagging $i ---"
  sed -n "$i"p profiles/emoji.txt | tr '|' '\n' | grep -v '^c:' > a
  sed -n "$i"p profiles/emoji.txt | tr '|' '\n' | grep '^c:' | sed 's/^c://' | tree-tagger-portuguese2 | gsed -e '/^@/s/\(.*\)	\(.*\)	\(.*\)/\1	\2	twitterhandle/' -e '/<unknown>$/s/\(.*\)	\(.*\)	\(.*\)/\1	\2	\1/' -e '/^EMOJI/s/\(EMOJI_\)\(.*\)	\(.*\)	\(EMOJI_\)\(.*\)/\2	EMOJI	\L\5/g' -e '/^HASHTAG/s/\(HASHTAG\)\(#\)\(.*\)	\(.*\)	\(HASHTAG\)\(#\)\(.*\)/\2\3	HASHTAG	\L\7/' -e 's/\(.*\)	\(.*\)	\(.*\)/\1	\2	\L\3/' | tr '\n' '~' | sed 's/^/c:/' >> a
  tr '\n' '|' < a | sed 's/~$//' >> profiles/tagged.txt
  echo >> profiles/tagged.txt 
done 

}


tokenstypes () {

# speed: 1,000 tweets = 100 sec

rm -f profiles/tokens.txt profiles/types.txt

last=$( cat profiles/emoji.txt | wc -l | tr -dc '[0-9]' )

for i in $(eval echo {1..$last});
do
  echo "--- doing $i ---"
  sed -n "$i"p profiles/tagged.txt | tr '|' '\n' > i
  grep -v '^c:' i > a
  grep '^c:' i | sed 's/^c://' | tr '~' '\n' | sed -e '/http/s/\(.*\)	\(.*\)	\(.*\)/\1	NOUN.url	url/' -e '/bit.ly/s/\(.*\)	\(.*\)	\(.*\)/\1	NOUN.url	url/' -e '/.com/s/\(.*\)	\(.*\)	\(.*\)/\1	NOUN.url	url/'  | grep -E '	VERB|	ADJ|	NOUN|	HASHTAG|	EMOJI' | grep -v -e '<unknown>' -e '\&amp' | cut -f3 | grep -v '^_h' | sed -e "s/\([\*\.\!?,'/()\":;$\-]\)/ \1 /g" | tr ' ' '\n' | grep '[a-z]' | grep -v '^.$' | tr '\n' ' ' | tr -d '#' | tr '[:upper:]' '[:lower:]' | tr -s ' ' | sed 's/^/c:/' > b
  cat a b | tr '\n' '|' | sed 's/~$//' | tr -s '|' >> profiles/tokens.txt
  echo >> profiles/tokens.txt
  sort b | uniq > c
  cat a c | tr '\n' '|' | sed 's/~$//' | tr -s '|' >> profiles/types.txt
  echo >> profiles/types.txt
done 

}


toplemmas () {

cut -d'|' -f3 profiles/types.txt | sed 's/^c://' | tr ' ' '\n' | tr '[:upper:]' '[:lower:]' | grep '[a-z]' | sort | uniq -c | sort -nr | sed 's/^[ ]*//' | sed -f stoplist.sed > profiles/wordlist

head -1000 profiles/wordlist | cut -d' ' -f2 | nl -nrz | sed 's/^/v/' > profiles/selectedwords

}

columns () {

mkdir -p profiles/sas

rm -f profiles/columns

cut -d'|' -f1,3 profiles/types.txt > a

while read n word 
do
  echo "--- $n $word ---"
  rg -w $word a | cut -d'|' -f1 | sed -e "s/$/ "$n" 1/" >> profiles/columns 
done < profiles/selectedwords

sort profiles/columns | uniq > a ; mv a profiles/columns  # to avoid words whose accents were stripped to be duplicated in the same text ; SAS can't handle that

#cut -d' ' -f2 profiles/selectedwords | gwc -L 
#head -1 columns | cut -d' ' -f1 | gwc -L

cp profiles/columns profiles/sas/data.txt

}

datamatrix () {

mkdir -p temp

rm -f temp/*

cut -d' ' -f1 profiles/columns | uniq | sort > files

while read n word 
do
  echo "--- $n ---"
  rg -w $n profiles/columns | sort -t' ' -k1,1 > a
  echo "$n" > temp/$n
  join -a 1 -1 1 -2 1 -e 0 files a | sed "s/$/ $n 0/" | cut -d' ' -f3 >> temp/$n
done < profiles/selectedwords

echo "--- data.csv ...---"

awk '
        FNR==1 { col++ }
        FNR>max { max=FNR }
        { l[FNR,col]=$0 }
        END {
                for (i=1;i<=max;i++) {
                        for (j=1;j<=col;j++) {
                                printf "%-50s",l[i,j]
                        }
                        print ""
                }
        }
' temp/* > u
tr -s ' ' < u | tr ' ' ',' | sed 's/,$//' > profiles/data.csv

}

correlationmatrix () {

echo "--- python correlation ... ---"

sed 's;data.csv;profiles/data.csv;' corr.py > p
python3 p > profiles/correlation

}

wcount () {

rm -f w

last=$( cat profiles/tagged.txt | wc -l | tr -dc '[0-9]' )

for i in $(eval echo {1..$last});
do
  echo "--- wcount $i / $last ---"
  sed -n "$i"p profiles/tagged.txt | tr '|' '\n' > i
  id=$( grep 'u:' i | sed 's/u://' )
  grep '^c:' i | sed 's/^c://' | tr '~' '\n' | sed -e '/http/s/\(.*\)	\(.*\)	\(.*\)/\1	NOUN.url	url/' -e '/bit.ly/s/\(.*\)	\(.*\)	\(.*\)/\1	NOUN.url	url/' -e '/.com/s/\(.*\)	\(.*\)	\(.*\)/\1	NOUN.url	url/'  | grep -v -w PUNCT > y
  wcount=$( cat y | wc -l | tr -cd '[0-9]' )
  code=$( grep -w $id user_index.txt | cut -d' ' -f1 )
  echo "$code $wcount" >> w
done

sort -t' ' -k1,1 w > profiles/sas/wcount.txt

}

replieslikes () {

    cut -d' ' -f2,4,5 output > a  # user, replies, likes
    cut -d' ' -f2 output | sort | uniq | nl -nrz | tr '\t' ' ' > u

    last=$( cat u | wc -l | tr -dc '[0-9]' )
    rm -f profiles/sas/replies_likes.txt
    while read n user
    do
      echo "--- profiles/sas/replies_likes.txt $n / $last ---"
      likes=$( grep -w $user a | cut -d' ' -f2 | awk '{ s += $1} END {print s}' )
      replies=$( grep -w $user a | cut -d' ' -f3 | awk '{ s += $1} END {print s}' )
      echo "$user $replies $likes" >> profiles/sas/replies_likes.txt
    done < u

}

sas () {

echo "--- sas files ... ---"

# copy userclusters.tsv to profiles/sas from the sas directory for the main MD analysis 

nlines=$( cat profiles/emoji.txt | wc -l | tr -dc '[0-9]' )

tail +2 profiles/correlation | tr -s ' ' | sed 's/^/CORR /' > bottom
head -1 profiles/correlation | tr -s ' ' | sed 's/^[ ]*//' | sed "s/\(v......\)/$nlines/g" | sed 's/^/N . /' > n

sed 's;data.csv;profiles/data.csv;' std.py > p
python3 p > s 
tr -s ' ' < s | cut -d' ' -f2 | grep -v 'float' | tr '\n' ' ' | sed 's/^/STD	 . /' > std 
echo >> std

sed 's;data.csv;profiles/data.csv;' mean.py > p
python3 p > m 
tr -s ' ' < m | cut -d' ' -f2 | grep -v 'float' | tr '\n' ' ' | sed 's/^/MEAN . /' > mean
echo >> mean

cat mean std n bottom > profiles/sas/corr.txt

#replace % with pc
echo "PROC FORMAT library=work ;
  VALUE  \$userlabels" > profiles/sas/user_labels_format.sas
tr '\t' ' ' < user_index.txt | sed -e 's/\(.*\) \(.*\)/"\1" = "\2"/' -e 's/%/pc/g' >> profiles/sas/user_labels_format.sas
echo ";
run;
quit;" >> profiles/sas/user_labels_format.sas

#replace % with pc
echo "PROC FORMAT library=work ;
  VALUE  \$profilelexlabels" > profiles/sas/word_labels_format.sas
tr '\t' ' ' < profiles/selectedwords | sed -e 's/\(.*\) \(.*\)/"\1" = "\2"/' -e 's/%/pc/g' >> profiles/sas/word_labels_format.sas
echo ";
run;
quit;" >> profiles/sas/word_labels_format.sas

}

wordclouds () {

# requirement: data has been processed in SAS

# dimensions (using types)

mkdir -p profiles/wordclouds

rm -f profiles/wordclouds/profiles_dim*.png

for i in {1..7}
do
  column=$( echo " $i + 1 " | bc ) 
  cut -f1,"$column" profiles/sas/output_group"$group"_profiles/group"$group"_profiles_scores_only.tsv | tail +2 > a

  for pole in pos neg
  do
    echo "--- "f"$i""$pole"" ---" 

    if [ "$pole" == pos ] ; then
       sort -nr -k2,2 a | grep -v -e '\-' -e '	0' | head -100 | cut -f1 | sort -n > files
    else
       sort -n -k2,2 a | grep -e '\-' | grep -v -e '	0' | head -100 | cut -f1 | sort -n > files
    fi

    cut -d'|' -f1,3 profiles/types.txt | sed -e 's/id://' -e 's/c://' -e 's/|/ /g' | tr ' ' '~' | sed 's/~/ /' |  sort -t' ' -n -k1,1 > all

    join -1 1 -2 1 files all | cut -d' ' -f2 | tr '~' '\n' | sed -f wordclouds/stoplist.sed | sort | uniq -c | sort -nr | grep '[a-z]' | sed 's/^[ ]*//' | tr '\t' ' ' | sed 's/\(.*\) \(.*\)/\2, \1/' > profiles/wordclouds/wc.csv

    sed "s;FILENAME;profiles/wordclouds/profiles_dim_"$i""$pole"_wordcloud;" wordclouds/wcloud_template.py | sed -e '/colormap/s/^/#/' -e '/800)./s/^#//' -e 's;wordclouds/wc.csv;profiles/wordclouds/wc.csv;' > p
    python3 p
   
  done
done

}

examples () {

mkdir -p profiles/examples
rm -f profiles/examples/*

html2text -nobs profiles/sas/output_group"$group"_profiles/loadtable.html > a

rm -f x??
split -p'=====' a
ls x?? > files

while read file
do
  pole=$( grep '^Factor ' $file | cut -d' ' -f2,3 | sed -e 's/^/f/' -e 's/ //g' )
  grep '^[0-9]' $file | tr -dc '[:alpha:][:punct:][0-9]\n ' | sed 's/^/~/' | tr  '[:space:]()' ' ' | tr -s ' ' |  tr '~' '\n' | cut -d' ' -f2 | grep -v '^$' | sed "s/^/$pole /" 
done < files > profiles/examples/factors
rm -f x??

head -1 profiles/sas/output_group"$group"_profiles/group"$group"_profiles_scores.tsv | tr -d '\r' | tr '\t' '\n' > vars

for i in {1..7}
do
  column=$( echo " $i + 1 " | bc ) 
  cut -f1,"$column" profiles/sas/output_group"$group"_profiles/group"$group"_profiles_scores_only.tsv  | tail +2 > a

  for pole in pos neg
  do
    echo "--- "f"$i""$pole"" ---" 

    if [ "$pole" == pos ] ; then
       sort -nr -k2,2 a | grep -v '\-' | grep -v '	0' | head -20 | nl -nrz > files
    else
       sort -n -k2,2 a | grep '\-' | grep -v '	0' | head -20 | nl -nrz > files
    fi

    grep f"$i""$pole" profiles/examples/factors | sort -t' ' -k2,2 | cut -d' ' -f2 | sort > factor_words


    while read n file score
    do

      grep -m1 $file profiles/sas/output_group"$group"_profiles/group"$group"_profiles_scores.tsv | tr -d '\r' | tr '\t' '\n' > scores
      paste vars scores | tr '\t' ' ' | grep '^v' | grep -v ' 0$' | cut -d' ' -f1 | sort > vars_text
      join vars_text profiles/selectedwords | cut -d' ' -f2 | sort > vars_text_codes
      username=$( grep -w $file user_index.txt | cut -d' ' -f2 )      

      echo "---------------" 

      echo "# $n" 
      echo "score = $score"  
      echo "https://mobile.twitter.com/$username"
      echo

      grep -w $file profiles/profiles.txt | tr '|' '\n' | sed 's/c:/~/' | tr '~' '\n'    

      echo
      echo "Lemmas in this profile that loaded on the factor:"
      echo

      join vars_text_codes factor_words 

      echo 

    done < files > profiles/examples/examples_f"$i"_"$pole".txt

  done

done

rm -f vars factor_words scores vars_text vars_text_codes

}


#profiles
#tokenizing
#emoji
#treetagging
#tokenstypes
#toplemmas
#columns
#datamatrix
#correlationmatrix
#wcount ## SLOW
#replieslikes ## SLOW
#sas 

### RUN SAS

#wordclouds
#examples


# data sampling:
#                               N
#. user_index =                 36,472 => all users in the corpus
#. tagged, tokens, types, etc = 26,734 => have text in their profile
#. observed =                   23,400 => include at least one selectedword

