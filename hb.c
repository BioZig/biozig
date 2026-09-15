#include <stdio.h>

void hbCreateDecodeTables(int *limit, int *base, int *perm, int *length, int minLen, int maxLen, int alphaSize) {
    int pp, i, j, vec;
    pp = 0;
    for (i = minLen; i <= maxLen; i++)
        for (j = 0; j < alphaSize; j++)
            if (length[j] == i) { perm[pp] = j; pp++; };

    for (i = 0; i < 23; i++) base[i] = 0;
    for (i = 0; i < alphaSize; i++) base[length[i] + 1]++;

    for (i = 1; i < 23; i++) base[i] += base[i - 1];

    for (i = 0; i < 23; i++) limit[i] = 0;
    vec = 0;
    for (i = minLen; i <= maxLen; i++) {
        vec += (base[i + 1] - base[i]);
        limit[i] = vec - 1;
        vec <<= 1;
    }
    for (i = minLen + 1; i <= maxLen; i++) {
        base[i] = ((limit[i - 1] + 1) << 1) - base[i];
    }
}

int main() {
    int limit[23], base[23], perm[41];
    int length[41] = { 5, 4, 4, 6, 6, 6, 6, 6, 6, 5, 6, 4, 6, 5, 6, 6, 4, 6, 6, 5, 6, 6, 5, 5, 6, 5, 5, 4, 6, 6, 5, 6, 6, 6, 6, 6, 6, 6, 6, 6 };
    hbCreateDecodeTables(limit, base, perm, length, 4, 6, 40);
    printf("limit[4]=%d, limit[5]=%d, limit[6]=%d\n", limit[4], limit[5], limit[6]);
    printf("base[4]=%d, base[5]=%d, base[6]=%d\n", base[4], base[5], base[6]);
    return 0;
}
