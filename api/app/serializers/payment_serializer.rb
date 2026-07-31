class PaymentSerializer
  def self.call(payment)
    {
      id: payment.id,
      paid_on: payment.paid_on,
      paid_time: payment.paid_time,
      description: payment.description,
      amount_cents: payment.amount_cents,
      kind: payment.kind,
      student_id: payment.student_id,
      needs_review: payment.needs_review
    }
  end
end
