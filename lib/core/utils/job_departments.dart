// lib/core/utils/job_departments.dart
//
// Architecture Appendix G.5 — Job Department dropdown for Profile Edit
// and Directory Filter (distinct from the 4 JTEC academic Departments in
// departments_helper.dart — this list is about the alumnus's current
// workplace department, e.g. "Merchandising", "Dyeing").

import 'package:flutter/material.dart';

class JobDepartments {
  static const List<String> all = [
    'Accounts & Finance',
    'Audit',
    'Bonding & Heat Seal',
    'Buying QC/QA',
    'CAD',
    'EMS ',
    'Fabric Technologist',
    'Garments Technologist',
    'HR, Compliance & Administration',
    'IE- Dyeing',
    'IE- Garments Finishing',
    'IE- Knitting',
    'IE- Sample',
    'IE- Sewing',
    'IE- Washing',
    'IT',
    'Lean Manufacturing',
    'Maintenance',
    'Marketing',
    'Merchandising',
    'MIS',
    'Operations',
    'Pattern',
    'Planning',
    'Production- Cutting',
    'Production- Dyeing',
    'Production- Embroidery',
    'Production- Garments Finishing',
    'Production- Knitting',
    'Production- Printing',
    'Production- Sewing',
    'Production- Spinning',
    'Production- Textile Finishing',
    'Production- Washing',
    'Production- Weaving',
    'Production- Yarn Dyeing',
    'Quality Management System',
    'Quality Assurance',
    'Quality- Cutting',
    'Quality- Dyeing',
    'Quality- Embroidery',
    'Quality- Garments Finishing',
    'Quality- Knitting',
    'Quality- Printing',
    'Quality- Sample',
    'Quality- Sewing',
    'Quality- Spinning',
    'Quality- Store',
    'Quality- Textile Finishing',
    'Quality- Washing',
    'Quality- Weaving',
    'Quality- Yarn Dyeing',
    'R&D- Central',
    'R&D- Dyeing',
    'R&D- Knitting',
    'R&D- Printing',
    'R&D- Spinning',
    'R&D- Washing',
    'R&D- Weaving',
    'Supply Chain',
    'Technical',
    'Testing Lab',
    'Wash Technologist',
    'Others',
  ];

  static List<DropdownMenuItem<String>> getDropdownItems() {
    return all.map((dept) {
      return DropdownMenuItem(
        value: dept,
        child: Text(dept, maxLines: 1, overflow: TextOverflow.ellipsis),
      );
    }).toList();
  }
}
