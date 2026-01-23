import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { RefreshCw, CheckCircle, XCircle, Clock, Image } from 'lucide-react';
import toast from 'react-hot-toast';

const API_URL = process.env.REACT_APP_BACKEND_URL;

const formatPrice = (price) => {
  return new Intl.NumberFormat('fa-IR').format(price) + ' تومان';
};

const Payments = () => {
  const [payments, setPayments] = useState([]);
  const [loading, setLoading] = useState(true);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(0);
  const [statusFilter, setStatusFilter] = useState('pending');
  const [selectedPayment, setSelectedPayment] = useState(null);
  const [reviewNote, setReviewNote] = useState('');
  const [processing, setProcessing] = useState(false);

  useEffect(() => {
    fetchPayments();
  }, [page, statusFilter]);

  const fetchPayments = async () => {
    try {
      const params = new URLSearchParams();
      if (statusFilter) params.append('status', statusFilter);
      params.append('skip', page * 50);
      params.append('limit', 50);

      const response = await axios.get(`${API_URL}/api/payments?${params}`);
      setPayments(response.data.payments);
      setTotal(response.data.total);
    } catch (error) {
      toast.error('خطا در دریافت پرداخت‌ها');
    } finally {
      setLoading(false);
    }
  };

  const handleReview = async (status) => {
    if (!selectedPayment) return;
    setProcessing(true);
    try {
      await axios.put(`${API_URL}/api/payments/${selectedPayment.id}/review`, {
        status,
        admin_note: reviewNote
      });
      toast.success(status === 'approved' ? 'پرداخت تأیید شد' : 'پرداخت رد شد');
      setSelectedPayment(null);
      setReviewNote('');
      fetchPayments();
    } catch (error) {
      toast.error('خطا در بررسی پرداخت');
    } finally {
      setProcessing(false);
    }
  };

  return (
    <div className="space-y-6" data-testid="payments-page">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white">پرداخت‌ها (کارت به کارت)</h1>
          <p className="text-slate-400 text-sm mt-1">{total} پرداخت</p>
        </div>
        <div className="flex gap-2">
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="input w-40"
            data-testid="payment-status-filter"
          >
            <option value="">همه</option>
            <option value="pending">در انتظار بررسی</option>
            <option value="approved">تأیید شده</option>
            <option value="rejected">رد شده</option>
          </select>
          <button onClick={fetchPayments} className="btn-secondary">
            <RefreshCw size={18} />
          </button>
        </div>
      </div>

      {/* Pending Count Alert */}
      {statusFilter === 'pending' && payments.length > 0 && (
        <div className="glass-card p-4 border-amber-500/30 bg-amber-500/5">
          <div className="flex items-center gap-3">
            <Clock className="text-amber-500" size={24} />
            <div>
              <p className="text-amber-400 font-medium">{payments.length} پرداخت در انتظار بررسی</p>
              <p className="text-sm text-slate-400">لطفاً رسیدها را بررسی و تأیید یا رد کنید</p>
            </div>
          </div>
        </div>
      )}

      {/* Table */}
      <div className="glass-card overflow-hidden">
        <div className="overflow-x-auto">
          <table className="table">
            <thead>
              <tr>
                <th>شناسه</th>
                <th>کاربر</th>
                <th>مبلغ</th>
                <th>وضعیت</th>
                <th>تاریخ</th>
                <th>عملیات</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={6} className="text-center py-8">
                    <div className="spinner mx-auto"></div>
                  </td>
                </tr>
              ) : payments.length === 0 ? (
                <tr>
                  <td colSpan={6} className="text-center py-8 text-slate-400">
                    پرداختی یافت نشد
                  </td>
                </tr>
              ) : (
                payments.map((payment) => (
                  <tr key={payment.id} data-testid={`payment-row-${payment.id}`}>
                    <td className="font-mono text-blue-400 text-xs">{payment.id.slice(0, 8)}...</td>
                    <td>
                      <div>
                        <p className="text-white">{payment.user?.first_name || '-'}</p>
                        <p className="text-xs text-slate-500">@{payment.user?.username || '-'}</p>
                      </div>
                    </td>
                    <td className="font-mono text-lg">{formatPrice(payment.amount || 0)}</td>
                    <td>
                      <span className={`badge ${
                        payment.status === 'pending' ? 'badge-warning' :
                        payment.status === 'approved' ? 'badge-success' : 'badge-error'
                      }`}>
                        {payment.status === 'pending' ? 'در انتظار' :
                         payment.status === 'approved' ? 'تأیید شده' : 'رد شده'}
                      </span>
                    </td>
                    <td className="text-slate-400 text-sm">
                      {payment.created_at ? new Date(payment.created_at).toLocaleDateString('fa-IR') : '-'}
                    </td>
                    <td>
                      <button
                        onClick={() => setSelectedPayment(payment)}
                        className={`btn-secondary text-sm ${payment.status === 'pending' ? 'animate-pulse-glow' : ''}`}
                        data-testid={`review-payment-${payment.id}`}
                      >
                        {payment.status === 'pending' ? 'بررسی' : 'مشاهده'}
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Pagination */}
      {total > 50 && (
        <div className="flex justify-center gap-2">
          <button onClick={() => setPage(Math.max(0, page - 1))} disabled={page === 0} className="btn-secondary">
            قبلی
          </button>
          <span className="px-4 py-2 text-slate-400">صفحه {page + 1} از {Math.ceil(total / 50)}</span>
          <button onClick={() => setPage(page + 1)} disabled={(page + 1) * 50 >= total} className="btn-secondary">
            بعدی
          </button>
        </div>
      )}

      {/* Review Modal */}
      {selectedPayment && (
        <div className="modal-overlay" onClick={() => setSelectedPayment(null)}>
          <div className="modal-content p-6 max-w-lg" onClick={(e) => e.stopPropagation()}>
            <h2 className="text-xl font-bold text-white mb-6">بررسی پرداخت</h2>
            
            <div className="space-y-4 mb-6">
              <div className="flex justify-between">
                <span className="text-slate-400">مبلغ:</span>
                <span className="font-mono text-xl text-white">{formatPrice(selectedPayment.amount || 0)}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-400">کاربر:</span>
                <span className="text-white">{selectedPayment.user?.first_name} (@{selectedPayment.user?.username})</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-400">پلن:</span>
                <span className="text-white">{selectedPayment.order?.plan?.name || '-'}</span>
              </div>
            </div>

            {/* Receipt Image Placeholder */}
            <div className="glass-card p-8 text-center mb-6">
              <Image className="mx-auto text-slate-500 mb-2" size={48} />
              <p className="text-slate-400 text-sm">تصویر رسید</p>
              {selectedPayment.receipt_file_id && (
                <p className="text-xs text-slate-500 mt-2 font-mono">{selectedPayment.receipt_file_id}</p>
              )}
            </div>

            {selectedPayment.status === 'pending' && (
              <>
                <div className="mb-6">
                  <label className="block text-sm text-slate-400 mb-2">یادداشت (اختیاری)</label>
                  <textarea
                    value={reviewNote}
                    onChange={(e) => setReviewNote(e.target.value)}
                    className="input min-h-[80px]"
                    placeholder="دلیل رد یا توضیحات..."
                    data-testid="review-note-input"
                  />
                </div>

                <div className="flex gap-3">
                  <button
                    onClick={() => handleReview('approved')}
                    disabled={processing}
                    className="flex-1 btn-primary bg-green-600 hover:bg-green-500 flex items-center justify-center gap-2"
                    data-testid="approve-payment-btn"
                  >
                    <CheckCircle size={18} />
                    تأیید پرداخت
                  </button>
                  <button
                    onClick={() => handleReview('rejected')}
                    disabled={processing}
                    className="flex-1 btn-danger flex items-center justify-center gap-2"
                    data-testid="reject-payment-btn"
                  >
                    <XCircle size={18} />
                    رد پرداخت
                  </button>
                </div>
              </>
            )}

            {selectedPayment.status !== 'pending' && (
              <div className="text-center">
                <span className={`badge ${selectedPayment.status === 'approved' ? 'badge-success' : 'badge-error'} text-base px-4 py-2`}>
                  {selectedPayment.status === 'approved' ? 'تأیید شده' : 'رد شده'}
                </span>
                {selectedPayment.admin_note && (
                  <p className="text-slate-400 mt-4">{selectedPayment.admin_note}</p>
                )}
              </div>
            )}

            <button onClick={() => setSelectedPayment(null)} className="btn-secondary w-full mt-4">
              بستن
            </button>
          </div>
        </div>
      )}
    </div>
  );
};

export default Payments;
