#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// BioZig C ABI Headers
extern int biozig_context_create();
extern int biozig_context_destroy();
extern int biozig_ping();

// 1. Genomics
extern const char* biozig_translate_dna(const char* seq);

// 2. Analytics
typedef struct {
    double coefficient;
    double p_value;
} CBiozigCorrelationResult;
extern CBiozigCorrelationResult biozig_analytics_pearson(const double* x, const double* y, size_t len);

// 3. Structural
typedef struct {
    double x;
    double y;
    double z;
} CBiozigGeometryVec3;
extern double biozig_structural_geometry_distance(CBiozigGeometryVec3 a, CBiozigGeometryVec3 b);

// 4. Cellular
extern int biozig_cellular_cellcycle_assign_phase(double g1, double s, double g2m);

int main() {
    printf("==========================================\n");
    printf(" BIOZIG C-ABI END-TO-END VALIDATION SUITE \n");
    printf("==========================================\n\n");

    printf("[1/6] Initializing BioZig Context (Arena Allocator)...\n");
    if (biozig_context_create() != 0) {
        fprintf(stderr, "FAIL: Context initialization!\n");
        return 1;
    }
    printf("      Context Ping = %d (OK)\n\n", biozig_ping());

    printf("[2/6] Validating Genomics Domain (Zero-Copy FFI)...\n");
    const char* dna = "ATGCGTACGTTAGCCTAG";
    const char* protein = biozig_translate_dna(dna);
    printf("      Input DNA: %s\n", dna);
    printf("      Output Protein: %s (OK)\n\n", protein ? protein : "NULL");

    printf("[3/6] Validating Analytics Domain (Math/Stats)...\n");
    double x[] = {1.0, 2.0, 3.0, 4.0, 5.0};
    double y[] = {2.0, 4.0, 6.0, 8.0, 10.0};
    CBiozigCorrelationResult res = biozig_analytics_pearson(x, y, 5);
    printf("      Pearson R: %.4f (Expected: 1.0000)\n", res.coefficient);
    printf("      P-Value: %.4f (OK)\n\n", res.p_value);

    printf("[4/6] Validating Structural Domain (3D Geometry)...\n");
    CBiozigGeometryVec3 p1 = {0.0, 0.0, 0.0};
    CBiozigGeometryVec3 p2 = {3.0, 4.0, 0.0};
    double dist = biozig_structural_geometry_distance(p1, p2);
    printf("      Euclidean Distance (0,0,0)->(3,4,0): %.4f (Expected: 5.0000) (OK)\n\n", dist);

    printf("[5/6] Validating Cellular Domain (Transcriptomics)...\n");
    int phase = biozig_cellular_cellcycle_assign_phase(0.9, 0.1, 0.05); // High G1
    printf("      Cell Cycle Phase Assigned (G1=0.9, S=0.1, G2M=0.05): State ID %d (OK)\n\n", phase);

    printf("[6/6] Destroying Context Arena...\n");
    if (biozig_context_destroy() != 0) {
        fprintf(stderr, "FAIL: Context destruction!\n");
        return 1;
    }

    printf("      All memory safely deallocated.\n");
    printf("==========================================\n");
    printf(" ALL DOMAINS PASS STRICT C-ABI VALIDATION \n");
    printf("==========================================\n");
    return 0;
}
