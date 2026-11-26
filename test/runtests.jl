using ReTestItems
using HerbSearch
runtests(HerbSearch; tags=:fast)
# `realistic_searches_test` is slow (tags=:slow) and is not run by default.