from macapptree import get_app_bundle, get_tree
bundle = get_app_bundle("Finder")
tree = get_tree(bundle, max_depth=4)
print(f"top-level elements: {len(tree)}")
for el in tree[:1]:
    print(el.get("role"), el.get("name"), "children:", len(el.get("children", [])))
