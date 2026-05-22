from sentence_transformers import SentenceTransformer
m = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2")
v = m.encode(["The weather is lovely today."])
print("device:", m.device, "dim:", len(v[0]))   # expect dim: 384
