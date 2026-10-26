// Water Filter Stack
// An inline hose filter: tube sections that screw into each other, a hose
// inlet on top and a funnel cap with a hose outlet on the bottom. One section
// is modelled; print as many copies as you want layers. Fill each section
// with a filter layer (e.g. top: gravel, middle: sand, bottom: charcoal/sand).
//
//  - Each tube has a male thread at the bottom and a female thread at the top,
//    so any section screws onto any other
//  - The bottom of every tube is a perforated floor that holds the media in
//    and lets water drip through
//  - A cone seat above the male thread centers the joint and a flat ledge
//    seats on the rim of the tube below
//  - The top inlet has the same male neck as a tube, so it screws into the
//    top of any section. Its hose end is a female garden hose thread, so the
//    male end of a hose screws in (needs a standard 3/4" hose washer)
//  - The funnel cap screws onto the bottom tube and narrows to a male garden
//    hose thread, so the female end of the next hose screws on
//  - Either hose end can be switched to a barb for soft vinyl tubing
//
// Sand is finer than the floor holes: lay a coffee filter or a disc of cloth
// on the floor before pouring sand in.
//
// Printing: part = "print" lays out one of each piece on the bed, ready to
// slice: tube and inlet stand on their male threads, the cap stands upside
// down. Duplicate the tube in the slicer for more layers. No supports needed.

/* [Part to show / export] */
part = "print"; // ["print", "exploded", "assembled", "tube", "inlet", "cap", "cap_print", "section"]

/* [Color] */
print_color = "#EFE6D2"; // beige / off-white

/* [Tube] */
tube_od     = 38;   // outside diameter
tube_height = 77;   // total height of one section, including the bottom thread
wall        = 2.4;  // wall thickness inside the threaded neck

/* [Tube threads] */
thread_d     = 32;  // major diameter of the male thread (keep ~6 mm under tube_od)
thread_pitch = 4;   // mm per turn
thread_depth = 1.5;
thread_flank = 45;  // flank angle from horizontal; 45 prints without supports
neck_len     = 14;  // length of the male thread (3+ turns)
ledge_w      = 2;   // flat ring that seats on the rim of the tube below
clearance    = 0.35; // radial gap between male and female threads

/* [Filter floor] */
floor_t  = 2.4;  // floor thickness
hole_d   = 2.0;  // drain hole diameter
hole_gap = 1.6;  // solid plastic between holes

/* [Hose ends] */
inlet_type  = "female_ght"; // ["female_ght", "male_ght", "barb"]
outlet_type = "male_ght";   // ["male_ght", "barb"]
// 3/4" garden hose thread (GHT): 1.0625" major, 11.5 threads per inch
ght_d       = 26.6;  // printed male: slightly under 26.99 so it fits brass couplings
ght_female_d = 26.99; // printed female: nominal size, plus ght_clear
ght_clear   = 0.35;
ght_pitch   = 25.4 / 11.5;
ght_depth   = 1.3;
ght_len     = 14;    // male thread length
ght_female_len = 12; // female thread length
ght_bore    = 16;
washer_d    = 25.8;  // pocket for a standard 3/4" hose washer
washer_t    = 3;
inlet_bore  = 14;
// barb for soft tubing (14 = 1/2" ID tubing)
barb_d      = 14;
barb_rings  = 4;
barb_ring_h = 5;
barb_bore   = 8;
cap_wall    = 3;  // wall thickness of the funnel cone

/* [Display] */
explode_gap = 25;
plate_gap   = 10;  // space between parts on the print bed

$fn = 120;

// ---------- derived sizes ----------
R           = tube_od / 2;
r_maj       = thread_d / 2;
r_min       = r_maj - thread_depth;
neck_bore_r = r_min - wall;
body_bore_r = r_min + clearance;     // matches the female thread core
seat_top_r  = R - ledge_w;
seat_h      = seat_top_r - r_min;    // 45 degree cone from neck to ledge
socket_depth = seat_h + neck_len + 1.5;
stack_step  = tube_height - neck_len - seat_h;  // height gained per extra tube
shoulder_z  = neck_len + seat_h;     // where the full-width body starts

assert(R - (r_maj + clearance) >= 2, "tube_od too small for thread_d: wall behind the female thread is under 2 mm");

// ---------- threads ----------
// Helical trapezoid ridge from z0 - pitch to z1 + pitch (trim it afterwards).
module thread_ridge(r_root, r_crest, pitch, z0, z1, flank, fn = $fn) {
    depth   = r_crest - r_root;
    w_crest = pitch * 0.125;
    w_root  = w_crest + 2 * depth * tan(flank);
    assert(w_root < pitch, "thread too deep for this pitch and flank angle");
    steps = ceil((z1 - z0 + 2 * pitch) / pitch * fn);
    profile = [[r_root, -w_root / 2], [r_crest, -w_crest / 2],
               [r_crest, w_crest / 2], [r_root, w_root / 2]];
    pts = [for (i = [0:steps]) let(a = i * 360 / fn, zc = z0 - pitch + i * pitch / fn)
               for (p = profile) [p[0] * cos(a), p[0] * sin(a), zc + p[1]]];
    faces = concat(
        [[3, 2, 1, 0]],
        [for (i = [0:steps - 1], j = [0:3])
            [i * 4 + j, i * 4 + (j + 1) % 4, (i + 1) * 4 + (j + 1) % 4, (i + 1) * 4 + j]],
        [[steps * 4, steps * 4 + 1, steps * 4 + 2, steps * 4 + 3]]);
    polyhedron(pts, faces);
}

// Male thread standing on z = 0, with a lead-in chamfer at the bottom.
module male_thread(d, pitch, depth, length, flank) {
    r2 = d / 2;
    r1 = r2 - depth;
    intersection() {
        union() {
            cylinder(r = r1, h = length);
            thread_ridge(r1 - 0.01, r2, pitch, 0, length, flank);
        }
        union() {
            cylinder(r1 = r1, r2 = r2 + 0.01, h = depth);
            translate([0, 0, depth]) cylinder(r = r2 + 0.01, h = length - depth);
        }
    }
}

// Shape to subtract for a female thread: the male thread, grown by clearance.
module female_thread_cut(d, pitch, depth, length, flank, clear) {
    r2 = d / 2 + clear;
    r1 = r2 - depth;
    intersection() {
        union() {
            cylinder(r = r1, h = length);
            thread_ridge(r1 - 0.01, r2, pitch, 0, length, flank);
        }
        cylinder(r = r2 + 1, h = length);
    }
}

// Female socket cut, hanging down from the rim at z = 0.
module socket_cut() {
    translate([0, 0, -socket_depth])
        female_thread_cut(thread_d, thread_pitch, thread_depth, socket_depth + 1,
                          thread_flank, clearance);
    // cone seat that matches the male shoulder
    translate([0, 0, -seat_h - 0.01])
        cylinder(h = seat_h + 0.02, r1 = r_min + clearance, r2 = seat_top_r + clearance);
}

// Male neck + cone seat shared by the tubes and the inlet (solid; bore it out).
module male_neck() {
    male_thread(thread_d, thread_pitch, thread_depth, neck_len, thread_flank);
    translate([0, 0, neck_len - 0.01])
        cylinder(h = seat_h + 0.01, r1 = r_min, r2 = seat_top_r);
}

// ---------- perforated floor ----------
// Built in 2D and extruded: much faster than drilling hundreds of 3D holes.
module filter_floor() {
    sp = hole_d + hole_gap;
    rr = neck_bore_r - hole_d / 2 - 0.8;
    n  = ceil(rr / sp) + 1;
    linear_extrude(floor_t)
        difference() {
            circle(r = neck_bore_r + 0.01);
            for (j = [-n:n], i = [-n:n]) {
                x = (i + (j % 2 == 0 ? 0 : 0.5)) * sp;
                y = j * sp * sqrt(3) / 2;
                if (norm([x, y]) <= rr) translate([x, y]) circle(d = hole_d, $fn = 12);
            }
        }
}

// ---------- tube section ----------
module tube() {
    H = tube_height;
    flare_h = body_bore_r - neck_bore_r;  // 45 degree widening inside
    difference() {
        union() {
            male_neck();
            translate([0, 0, shoulder_z]) cylinder(h = H - shoulder_z, r = R);
        }
        translate([0, 0, -1]) cylinder(h = shoulder_z + 1.01, r = neck_bore_r);
        translate([0, 0, shoulder_z])
            cylinder(h = flare_h, r1 = neck_bore_r, r2 = body_bore_r);
        translate([0, 0, shoulder_z + flare_h - 0.01]) cylinder(h = H, r = body_bore_r);
        translate([0, 0, H]) socket_cut();
    }
    filter_floor();
}

// ---------- hose spigots (free end at z = 0) ----------
function spigot_core_r(t) = t == "male_ght" ? ght_d / 2 - ght_depth : barb_d / 2 - 0.8;
function spigot_bore_r(t) = t == "male_ght" ? ght_bore / 2 : barb_bore / 2;
function spigot_len(t)    = t == "male_ght" ? ght_len + 4 : barb_rings * barb_ring_h;

module spigot(t) {
    if (t == "male_ght") {
        // thread from the end face up, then a plain neck so the hose
        // coupling's washer seals on the end face before the nut bottoms out
        male_thread(ght_d, ght_pitch, ght_depth, ght_len, 30);
        cylinder(r = spigot_core_r(t), h = spigot_len(t) + 0.01);
    } else {
        cylinder(r = spigot_core_r(t), h = spigot_len(t) + 0.01);
        for (k = [0:barb_rings - 1])
            translate([0, 0, k * barb_ring_h])
                cylinder(h = barb_ring_h * 0.8, r1 = spigot_core_r(t), r2 = barb_d / 2);
    }
}

// ---------- funnel cap (as used: hose outlet pointing down) ----------
out_core_r = spigot_core_r(outlet_type);
out_bore_r = spigot_bore_r(outlet_type);
out_len    = spigot_len(outlet_type);
cone_h     = R - out_core_r;
cap_height = out_len + cone_h + 2 + socket_depth;

module cap() {
    z_cone = out_len;
    z_body = z_cone + cone_h;
    off    = cap_wall * sqrt(2);                       // horizontal wall at 45 degrees
    z_in0  = z_cone + out_bore_r - (out_core_r - off);
    z_in1  = z_cone + body_bore_r - (out_core_r - off);
    difference() {
        union() {
            spigot(outlet_type);
            translate([0, 0, z_cone]) cylinder(h = cone_h, r1 = out_core_r, r2 = R);
            translate([0, 0, z_body]) cylinder(h = cap_height - z_body, r = R);
        }
        translate([0, 0, -1]) cylinder(h = z_in0 + 1.01, r = out_bore_r);
        translate([0, 0, z_in0]) cylinder(h = z_in1 - z_in0, r1 = out_bore_r, r2 = body_bore_r);
        translate([0, 0, z_in1 - 0.01]) cylinder(h = cap_height, r = body_bore_r);
        translate([0, 0, cap_height]) socket_cut();
    }
}

// ---------- top inlet (as used and as printed: male neck down) ----------
in_collar_h  = 3;                               // full-width band above the ledge
in_collar_z  = shoulder_z + in_collar_h;        // top of that band
in_housing_r = ght_female_d / 2 + ght_clear + 2.5;
in_washer_z  = in_collar_z + (neck_bore_r - inlet_bore / 2) + 1.5;
in_spig_r    = spigot_core_r(inlet_type);
in_spig_z    = in_collar_z + (R - in_spig_r);  // where the spigot starts
inlet_height = inlet_type == "female_ght"
    ? in_washer_z + washer_t + ght_female_len
    : in_spig_z + spigot_len(inlet_type);

module inlet() {
    female = inlet_type == "female_ght";
    bore_r = female ? inlet_bore / 2 : spigot_bore_r(inlet_type);
    neck_h = neck_bore_r - bore_r;               // 45 degree narrowing inside
    difference() {
        union() {
            male_neck();
            translate([0, 0, shoulder_z]) cylinder(h = in_collar_h, r = R);
            if (female) {
                translate([0, 0, in_collar_z])
                    cylinder(h = R - in_housing_r + 0.01, r1 = R, r2 = in_housing_r);
                translate([0, 0, in_collar_z])
                    cylinder(h = inlet_height - in_collar_z, r = in_housing_r);
            } else {
                translate([0, 0, in_collar_z])
                    cylinder(h = in_spig_z - in_collar_z + 0.01, r1 = R, r2 = in_spig_r);
                translate([0, 0, inlet_height]) mirror([0, 0, 1]) spigot(inlet_type);
            }
        }
        translate([0, 0, -1]) cylinder(h = in_collar_z + 1.01, r = neck_bore_r);
        translate([0, 0, in_collar_z]) cylinder(h = neck_h, r1 = neck_bore_r, r2 = bore_r);
        translate([0, 0, in_collar_z + neck_h - 0.01]) cylinder(h = inlet_height, r = bore_r);
        if (female) {
            // washer pocket, then the female hose thread up to the top
            translate([0, 0, in_washer_z]) cylinder(h = washer_t + 0.01, d = washer_d);
            translate([0, 0, in_washer_z + washer_t])
                female_thread_cut(ght_female_d, ght_pitch, ght_depth, ght_female_len + 1,
                                  30, ght_clear);
            // lead-in chamfer at the opening
            translate([0, 0, inlet_height - 1])
                cylinder(h = 1.01, r1 = ght_female_d / 2 + ght_clear - ght_depth,
                         r2 = ght_female_d / 2 + ght_clear + 0.3);
        }
    }
}

// ---------- stack ----------
module stack(gap) {
    base = cap_height - shoulder_z;
    cap();
    translate([0, 0, base + gap]) tube();
    translate([0, 0, base + stack_step + 2 * gap]) inlet();
}

// ---------- print bed layout ----------
module print_plate() {
    step = tube_od + plate_gap;
    translate([-step, 0, 0]) inlet();
    tube();
    translate([step, 0, cap_height]) rotate([180, 0, 0]) cap();
}

color(print_color) {
    if (part == "print")          print_plate();
    else if (part == "exploded")  stack(explode_gap);
    else if (part == "assembled") stack(0);
    else if (part == "tube")      tube();
    else if (part == "inlet")     inlet();
    else if (part == "cap")       cap();
    else if (part == "cap_print") translate([0, 0, cap_height]) rotate([180, 0, 0]) cap();
    else if (part == "section")   difference() { stack(0); translate([0, -100, -10]) cube([200, 200, 800]); }
}
