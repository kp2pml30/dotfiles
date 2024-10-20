import secrets

with open("words.txt", "rt") as f:
	lines = [l.strip() for l in f]

bits = secrets.randbits(300)
mx = len(lines)
while bits > 0:
	print(lines[bits % mx], end=' ')
	bits //= mx
print()
