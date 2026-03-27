# Training Data Export
# Generated: 2026-03-26 22:42:38 +0100
# Use: rails training_data:import

puts 'Importing training data...'

# Training Sources
source_2 = TrainingSource.find_or_create_by(id: 2) do |s|
  s.title = "VAN GROOT SPEL TOT SERIE AMERICAINE"
  s.author = "Rene Gabriels"
  s.publication_year = 1944
  s.publisher = "H. L. SMIT & ZOON»HENGELO"
  s.language = "nl"
  s.notes = ""
end

# Training Concepts
concept_3 = TrainingConcept.find_or_create_by(id: 3) do |c|
  c.title = "Konterspiel"
  c.title_de = "Konterspiel"
  c.title_en = nil
  c.short_description = "Grundlagen des Konterspiels beim Dreiband"
  c.short_description_de = "Grundlagen des Konterspiels beim Dreiband"
  c.short_description_en = nil
  c.full_description = "Das Konterspiel ist eine fundamentale Technik im Dreiband-Billard. \nDabei wird der erste Ball so angespielt, dass der Spielball über zwei \nBanden zum zweiten Ball läuft.\n\nWichtig ist dabei:\n- Die richtige Bandenwahl\n- Die korrekte Kraftdosierung\n- Der optimale Effet\n"
  c.full_description_de = "Das Konterspiel ist eine fundamentale Technik im Dreiband-Billard. \nDabei wird der erste Ball so angespielt, dass der Spielball über zwei \nBanden zum zweiten Ball läuft.\n\nWichtig ist dabei:\n- Die richtige Bandenwahl\n- Die korrekte Kraftdosierung\n- Der optimale Effet\n"
  c.full_description_en = nil
  c.source_language = "de"
  c.translations_synced_at = nil
end

concept_4 = TrainingConcept.find_or_create_by(id: 4) do |c|
  c.title = "Rückläufer"
  c.title_de = "Rückläufer"
  c.title_en = nil
  c.short_description = "Technik des Rücklaufs mit Rückwärtseffet"
  c.short_description_de = "Technik des Rücklaufs mit Rückwärtseffet"
  c.short_description_en = nil
  c.full_description = "Der Rückläufer ist eine Technik, bei der der Spielball nach dem \nTreffen der Objektbälle zurückläuft. Dies wird durch starkes \nRückwärtseffet erreicht.\n\nAnwendung:\n- Positionsspiel\n- Defensive Stöße\n- Bandenspiel\n"
  c.full_description_de = "Der Rückläufer ist eine Technik, bei der der Spielball nach dem \nTreffen der Objektbälle zurückläuft. Dies wird durch starkes \nRückwärtseffet erreicht.\n\nAnwendung:\n- Positionsspiel\n- Defensive Stöße\n- Bandenspiel\n"
  c.full_description_en = nil
  c.source_language = "de"
  c.translations_synced_at = nil
end

# Training Examples
example_3 = TrainingExample.find_or_create_by(id: 3) do |e|
  e.training_concept_id = 3
  e.sequence_number = 1
  e.title = "Einfaches Konterspiel mit kurzer Linie"
  e.title_de = "Einfaches Konterspiel mit kurzer Linie"
  e.title_en = nil
  e.ideal_stroke_parameters_text = "- Effet: Rechtseffet (ca. 1 Spitze)\n- Kraft: Mittel (ca. 60%)\n- Zielpunkt am Ball 1: Voll\n- Lauflinie: Kurze Bande -> Lange Bande\n"
  e.ideal_stroke_parameters_text_de = "- Effet: Rechtseffet (ca. 1 Spitze)\n- Kraft: Mittel (ca. 60%)\n- Zielpunkt am Ball 1: Voll\n- Lauflinie: Kurze Bande -> Lange Bande\n"
  e.ideal_stroke_parameters_text_en = nil
  e.source_language = "de"
  e.source_notes = nil
  e.translations_synced_at = nil
end

example_4 = TrainingExample.find_or_create_by(id: 4) do |e|
  e.training_concept_id = 4
  e.sequence_number = 1
  e.title = "Einfacher Rückläufer"
  e.title_de = "Einfacher Rückläufer"
  e.title_en = nil
  e.ideal_stroke_parameters_text = "- Effet: Starkes Rückwärtseffet (untere Hälfte des Balls)\n- Kraft: Kräftig (ca. 75%)\n- Zielpunkt: Voll auf Ball 1\n- Queue-Haltung: Leicht nach unten geneigt\n"
  e.ideal_stroke_parameters_text_de = "- Effet: Starkes Rückwärtseffet (untere Hälfte des Balls)\n- Kraft: Kräftig (ca. 75%)\n- Zielpunkt: Voll auf Ball 1\n- Queue-Haltung: Leicht nach unten geneigt\n"
  e.ideal_stroke_parameters_text_en = nil
  e.source_language = "de"
  e.source_notes = nil
  e.translations_synced_at = nil
end

# Source Attributions
# ActiveStorage Blobs for TrainingSources
blob_50000004 = ActiveStorage::Blob.find_or_create_by(key: "497opsw1nzrpggtn0nleq1xqg6w5") do |b|
  b.filename = "3-van grote spel.pdf"
  b.content_type = "application/pdf"
  b.metadata = {"identified"=>true, "analyzed"=>true}
  b.byte_size = 21647121
  b.checksum = "yzDmqNvmsgpAZLnouvgGWQ=="
  b.service_name = 'local'
end

unless source_2.source_files.where(id: blob_50000004.attachments.first&.id).exists?
  source_2.source_files.attach(blob_50000004)
end

blob_50000005 = ActiveStorage::Blob.find_or_create_by(key: "jp7yedc76d2ruenpwe5gk1gz6vlh") do |b|
  b.filename = "GTG-Blat1.jpg"
  b.content_type = "image/jpeg"
  b.metadata = {"identified"=>true, "analyzed"=>true}
  b.byte_size = 3686145
  b.checksum = "JZ6TiBpwacVXCO/KrSM7NQ=="
  b.service_name = 'local'
end

unless source_2.source_files.where(id: blob_50000005.attachments.first&.id).exists?
  source_2.source_files.attach(blob_50000005)
end

puts '✅ Training data imported successfully!'
