# frozen_string_literal: true

module Diagnostics
  # Symbole der Status-Stufen. Ausserhalb des Struct-Blocks, weil Konstanten in einem Block
  # zur Laufzeit im umgebenden Namespace landen (Lint/ConstantDefinitionInBlock).
  STATUS_ICONS = {ok: "✅", warn: "⚠️ ", fail: "❌", skip: "⏭️ ", info: "ℹ️ "}.freeze

  # Ein einzelnes Diagnose-Ergebnis.
  #
  # `status` bewusst fuenfstufig statt boolesch: der haeufigste Betriebsfall dieser Kette ist nicht
  # "kaputt", sondern "nicht zutreffend" (ein Region Server braucht keinen Region-Server-Zugang) oder
  # "kann von hier nicht geprueft werden" (Netzwerk aus). Ein boolesches OK/FEHLER wuerde beides zu
  # Fehlalarm machen — und Fehlalarme sind der Grund, warum Diagnose-Tools nicht mehr gelesen werden.
  #
  #   :ok    geprueft, in Ordnung
  #   :warn  auffaellig, aber kein Blocker (z.B. Fallback statt ausgerolltem Weg)
  #   :fail  die Kette ist an dieser Stelle unterbrochen
  #   :skip  trifft auf diese Rolle nicht zu / wurde bewusst nicht geprueft
  #   :info  reine Bestandsangabe ohne Bewertung
  Check = Struct.new(:name, :status, :detail, :hint, keyword_init: true) do
    def ok? = status == :ok

    def failed? = status == :fail

    def warned? = status == :warn

    def icon = STATUS_ICONS.fetch(status, "  ")
  end
end
