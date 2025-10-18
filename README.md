# Corpus Linguistics - Study 1 - Luciana

## Phase 1 - Extraction of 5 factors

This phase was about the extraction of 5 factors from the Lexical Multi-Dimensional Analysis of social media profiles and involved the following steps:

1. Code integrity check by reproducing the previous results on a macOS platform
2. Code integrity check by reproducing the previous results on an Ubuntu platform
3. Development of code adaptation and corrections
4. Extraction of 5 factors using the revised code

The integrity checking resulted consistent in both platforms. However, the most accurate reproduction was on the Ubuntu platform. Therefore, Ubuntu was chosen for the development of the code adaptation and corrections, and for the factor extraction processing.

The code adaptations and corrections are listed below:

1. In `profiles_group_2.sh`, the function `examples` was patched with `extract_factors.py` to extract data from `loadtable.html` to `examples/factors` because the former shell script snippet was not working
2. The file `followers.txt` was retrieved from `group2/sas/` and included in `group2/profiles/sas/`
3. `group2_profiles.sas` required troubleshooting and adaptation for extracting 5 factors

The new results are available in `3_new_project_5_factors`.
