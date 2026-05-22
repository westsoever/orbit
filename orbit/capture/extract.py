from __future__ import annotations

CAPTURE_ROLES = {"AXTextField", "AXTextArea", "AXStaticText", "AXDocument", "AXWebArea"}

def flatten_text_atoms(tree, _path: str = "") -> list[dict]:
    if isinstance(tree, dict):
        nodes = [tree]
    elif isinstance(tree, list):
        nodes = tree
    else:
        return []
    results = []
    for i, node in enumerate(nodes):
        if not isinstance(node, dict):
            continue
        path = f"{_path}/{i}"
        role = node.get("role", "")
        text = (node.get("value") or node.get("name") or "").strip()
        if role in CAPTURE_ROLES and text:
            results.append({
                "role": role,
                "label": node.get("description") or node.get("role_description"),
                "text": text,
                "element_path": path,
                "element_hash": node.get("id"),
            })
        children = node.get("children") or []
        results.extend(flatten_text_atoms(children, path))
    return results
