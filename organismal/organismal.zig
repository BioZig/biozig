const std = @import("std");

pub const phenotype = @import("phenotype/phenotype.zig");
pub const disease = @import("disease/disease.zig");
pub const development = @import("development/development.zig");
pub const physiology = @import("physiology/physiology.zig");
pub const anatomy = @import("anatomy/anatomy.zig");

test {
    // Force compilation and execution of submodule tests
    _ = phenotype;
    _ = disease;
    _ = development;
    _ = physiology;
    _ = anatomy;
}

/// Link mapping a Phenotype to a Disease (e.g. symptom/presentation of a disease).
pub const PhenotypeDiseaseLink = struct {
    phenotype_id: []const u8,
    disease_id: []const u8,
};

/// Link mapping a Disease to an AnatomicalStructure (e.g. organ affected by the disease).
pub const DiseaseAnatomyLink = struct {
    disease_id: []const u8,
    anatomy_id: []const u8,
};

/// Link mapping a Phenotype to a PhysiologicalSystem (e.g. system expressing the phenotype).
pub const PhenotypePhysiologyLink = struct {
    phenotype_id: []const u8,
    physiology_id: []const u8,
};

/// Link mapping a PhysiologicalSystem to an AnatomicalStructure (e.g. structures making up the system).
pub const PhysiologyAnatomyLink = struct {
    physiology_id: []const u8,
    anatomy_id: []const u8,
};

/// Container holding all typed links connecting the organismal sub-layers.
pub const OrganismalLinks = struct {
    phenotype_disease: []const PhenotypeDiseaseLink,
    disease_anatomy: []const DiseaseAnatomyLink,
    phenotype_physiology: []const PhenotypePhysiologyLink,
    physiology_anatomy: []const PhysiologyAnatomyLink,

    /// Initializes an OrganismalLinks container.
    pub fn init(
        pd: []const PhenotypeDiseaseLink,
        da: []const DiseaseAnatomyLink,
        pp: []const PhenotypePhysiologyLink,
        pa: []const PhysiologyAnatomyLink,
    ) OrganismalLinks {
        return .{
            .phenotype_disease = pd,
            .disease_anatomy = da,
            .phenotype_physiology = pp,
            .physiology_anatomy = pa,
        };
    }

    /// Validates the referential integrity of all links against their corresponding collections/hierarchies.
    /// Returns error if any link references an ID not present in the respective sub-layers.
    pub fn validate(
        self: OrganismalLinks,
        phenotypes: phenotype.PhenotypeCollection,
        diseases: disease.DiseaseCollection,
        physiology_systems: []const physiology.PhysiologicalSystem,
        anatomy_hierarchy: anatomy.AnatomicalHierarchy,
    ) !void {
        // 1. Phenotype <-> Disease links
        for (self.phenotype_disease) |link| {
            if (phenotypes.lookup(link.phenotype_id) == null) return error.InvalidPhenotypeReference;
            if (diseases.lookup(link.disease_id) == null) return error.InvalidDiseaseReference;
        }

        // 2. Disease <-> Anatomy links
        for (self.disease_anatomy) |link| {
            if (diseases.lookup(link.disease_id) == null) return error.InvalidDiseaseReference;
            if (anatomy_hierarchy.lookup(link.anatomy_id) == null) return error.InvalidAnatomyReference;
        }

        // 3. Phenotype <-> Physiology links
        for (self.phenotype_physiology) |link| {
            if (phenotypes.lookup(link.phenotype_id) == null) return error.InvalidPhenotypeReference;
            var phys_found = false;
            for (physiology_systems) |sys| {
                if (std.mem.eql(u8, sys.id, link.physiology_id)) {
                    phys_found = true;
                    break;
                }
            }
            if (!phys_found) return error.InvalidPhysiologyReference;
        }

        // 4. Physiology <-> Anatomy links
        for (self.physiology_anatomy) |link| {
            var phys_found = false;
            for (physiology_systems) |sys| {
                if (std.mem.eql(u8, sys.id, link.physiology_id)) {
                    phys_found = true;
                    break;
                }
            }
            if (!phys_found) return error.InvalidPhysiologyReference;
            if (anatomy_hierarchy.lookup(link.anatomy_id) == null) return error.InvalidAnatomyReference;
        }
    }
};

test "Organismal Integration: validation of linked references" {
    // 1. Setup Phenotypes
    const p1 = phenotype.Phenotype.init("HP:01", "P1", "Desc1", .qualitative, &[_]phenotype.MetadataEntry{});
    const phenotypes_arr = [_]phenotype.Phenotype{p1};
    const phenotypes = phenotype.PhenotypeCollection.init(&phenotypes_arr);

    // 2. Setup Diseases
    const d1 = disease.Disease.init("MONDO:01", "D1", .genetic, &[_]disease.MetadataEntry{}, &[_]disease.DiseaseRelationship{});
    const diseases_arr = [_]disease.Disease{d1};
    const diseases = disease.DiseaseCollection.init(&diseases_arr);

    // 3. Setup Physiology
    const sys1 = physiology.PhysiologicalSystem.init("SYS:01", "S1", null, &[_]physiology.MetadataEntry{});
    const physiology_systems = [_]physiology.PhysiologicalSystem{sys1};

    // 4. Setup Anatomy
    const anat1 = anatomy.AnatomicalStructure.init("UBERON:01", "A1");
    const anatomy_arr = [_]anatomy.AnatomicalStructure{anat1};
    const anatomy_hierarchy = anatomy.AnatomicalHierarchy.init(&anatomy_arr, &[_]anatomy.AnatomicalRelationship{});

    // 5. Test valid linkages
    const pd = [_]PhenotypeDiseaseLink{.{ .phenotype_id = "HP:01", .disease_id = "MONDO:01" }};
    const da = [_]DiseaseAnatomyLink{.{ .disease_id = "MONDO:01", .anatomy_id = "UBERON:01" }};
    const pp = [_]PhenotypePhysiologyLink{.{ .phenotype_id = "HP:01", .physiology_id = "SYS:01" }};
    const pa = [_]PhysiologyAnatomyLink{.{ .physiology_id = "SYS:01", .anatomy_id = "UBERON:01" }};

    const links_valid = OrganismalLinks.init(&pd, &da, &pp, &pa);
    try links_valid.validate(phenotypes, diseases, &physiology_systems, anatomy_hierarchy);

    // 6. Test invalid linkages
    const pd_invalid = [_]PhenotypeDiseaseLink{.{ .phenotype_id = "HP:INVALID", .disease_id = "MONDO:01" }};
    const links_invalid = OrganismalLinks.init(&pd_invalid, &da, &pp, &pa);
    try std.testing.expectError(error.InvalidPhenotypeReference, links_invalid.validate(phenotypes, diseases, &physiology_systems, anatomy_hierarchy));
}
