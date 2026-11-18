/// Versioned schema. Add a new entry for each schema bump; never edit old ones.
const int schemaVersion = 1;

const Map<int, List<String>> migrations = {
  1: [
    '''
    CREATE TABLE profile (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      name TEXT NOT NULL,
      student_no TEXT NOT NULL DEFAULT '',
      program TEXT NOT NULL DEFAULT '',
      year_level INTEGER NOT NULL DEFAULT 1,
      pin_hash TEXT,
      pin_salt TEXT,
      biometric INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    )''',
    '''
    CREATE TABLE terms (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      school_year TEXT NOT NULL,
      term TEXT NOT NULL CHECK (term IN ('1st','2nd','Summer')),
      is_current INTEGER NOT NULL DEFAULT 0,
      sort_order INTEGER NOT NULL,
      UNIQUE (school_year, term)
    )''',
    '''
    CREATE TABLE grade_scales (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      failing_equivalent REAL NOT NULL DEFAULT 5.0,
      is_default INTEGER NOT NULL DEFAULT 0
    )''',
    '''
    CREATE TABLE grade_scale_rows (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      scale_id INTEGER NOT NULL REFERENCES grade_scales(id) ON DELETE CASCADE,
      min_percent REAL NOT NULL CHECK (min_percent >= 0 AND min_percent <= 100),
      equivalent REAL NOT NULL
    )''',
    '''
    CREATE TABLE subjects (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      term_id INTEGER NOT NULL REFERENCES terms(id) ON DELETE CASCADE,
      code TEXT NOT NULL,
      title TEXT NOT NULL,
      units REAL NOT NULL CHECK (units > 0),
      instructor TEXT NOT NULL DEFAULT '',
      color_idx INTEGER NOT NULL DEFAULT 0,
      scale_id INTEGER REFERENCES grade_scales(id) ON DELETE SET NULL,
      avg_method TEXT NOT NULL DEFAULT 'mean',
      counts_in_gwa INTEGER NOT NULL DEFAULT 1,
      final_grade REAL,
      final_mark TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      UNIQUE (term_id, code COLLATE NOCASE)
    )''',
    '''
    CREATE TABLE components (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      subject_id INTEGER NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      weight REAL NOT NULL CHECK (weight > 0 AND weight <= 100),
      sort_order INTEGER NOT NULL DEFAULT 0
    )''',
    '''
    CREATE TABLE scores (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      component_id INTEGER NOT NULL REFERENCES components(id) ON DELETE CASCADE,
      title TEXT NOT NULL,
      score REAL,
      total REAL NOT NULL CHECK (total > 0),
      date TEXT NOT NULL,
      note TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      CHECK (score IS NULL OR (score >= 0 AND score <= total))
    )''',
    'CREATE INDEX idx_subjects_term ON subjects(term_id)',
    'CREATE INDEX idx_components_subject ON components(subject_id)',
    'CREATE INDEX idx_scores_component ON scores(component_id)',
    'CREATE INDEX idx_scores_date ON scores(date)',
    'CREATE INDEX idx_scale_rows_scale ON grade_scale_rows(scale_id)',
  ],
};
