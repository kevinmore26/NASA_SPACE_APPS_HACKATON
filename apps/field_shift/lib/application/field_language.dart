enum FieldLanguage {
  english('en', 'English'),
  spanish('es', 'Español');

  const FieldLanguage(this.code, this.label);

  final String code;
  final String label;

  String pick(String english, String spanish) =>
      this == FieldLanguage.english ? english : spanish;

  static FieldLanguage fromCode(Object? code) =>
      code == 'es' ? FieldLanguage.spanish : FieldLanguage.english;
}
