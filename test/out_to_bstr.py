"""
Konwertuje ciąg linii wyjściowych z interpretera do postaci stringa
bajtowego, który można wkleić do funkcji testującej.

Na przykład:

> 1
> 2
? 
> 3

Wynikiem będzie:

1\\n2\\n3\\n

"""

import sys
import re

for line in sys.stdin:
    match = re.search('.*> (\d+)', line)
    if not match:
        continue
    print(match.group(1) + '\\n', end='')