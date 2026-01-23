import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { RefreshCw, Eye, Search } from 'lucide-react';
import toast from 'react-hot-toast';

const API_URL = process.env.REACT_APP_BACKEND_URL;

const formatPrice = (price) => {
  return new Intl.NumberFormat('fa-IR').format(price) + ' تومان';
};

const statusLabels = {
  pending: { label: 'در انتظار پرداخت', class: 'badge-warning' },
  paid: { label: 'پرداخت شده', class: 'badge-info' },
  confirmed: { label: 'تأیید شده', class: 'badge-success' },
  cancelled: { label: 'لغو شده', class: 'badge-error' },
  expired: { label: 'منقضی شده', class: 'badge-default' }
};

const Orders = () => {
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(0);
  const [statusFilter, setStatusFilter] = useState('');
  const [selectedOrder, setSelectedOrder] = useState(null);

  useEffect(() => {
    fetchOrders();
  }, [page, statusFilter]);

  const fetchOrders = async () => {
    try {
      const params = new URLSearchParams();
      if (statusFilter) params.append('status', statusFilter);
      params.append('skip', page * 50);
      params.append('limit', 50);

      const response = await axios.get(`${API_URL}/api/orders?${params}`);
      setOrders(response.data.orders);
      setTotal(response.data.total);
    } catch (error) {
      toast.error('خطا در دریافت سفارشات');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="space-y-6" data-testid="orders-page">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white">سفارشات</h1>
          <p className="text-slate-400 text-sm mt-1">{total} سفارش</p>
        </div>
        <div className="flex gap-2">
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="input w-40"
            data-testid="status-filter"
          >
            <option value="">همه وضعیت‌ها</option>
            <option value="pending">در انتظار</option>
            <option value="paid">پرداخت شده</option>
            <option value="confirmed">تأیید شده</option>
            <option value="cancelled">لغو شده</option>
          </select>
          <button onClick={fetchOrders} className="btn-secondary">
            <RefreshCw size={18} />
          </button>
        </div>
      </div>

      {/* Table */}
      <div className="glass-card overflow-hidden">
        <div className="overflow-x-auto">
          <table className="table">
            <thead>
              <tr>
                <th>شناسه</th>
                <th>کاربر</th>
                <th>پلن</th>
                <th>مبلغ</th>
                <th>تخفیف</th>
                <th>وضعیت</th>
                <th>تاریخ</th>
                <th>عملیات</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={8} className="text-center py-8">
                    <div className="spinner mx-auto"></div>
                  </td>
                </tr>
              ) : orders.length === 0 ? (
                <tr>
                  <td colSpan={8} className="text-center py-8 text-slate-400">
                    سفارشی یافت نشد
                  </td>
                </tr>
              ) : (
                orders.map((order) => (
                  <tr key={order.id} data-testid={`order-row-${order.id}`}>
                    <td className="font-mono text-blue-400 text-xs">{order.id.slice(0, 8)}...</td>
                    <td>
                      <div>
                        <p className="text-white">{order.user?.first_name || '-'}</p>
                        <p className="text-xs text-slate-500">@{order.user?.username || '-'}</p>
                      </div>
                    </td>
                    <td>{order.plan?.name || '-'}</td>
                    <td className="font-mono">{formatPrice(order.final_price || 0)}</td>
                    <td>
                      {order.discount_code ? (
                        <span className="badge badge-info">{order.discount_code}</span>
                      ) : (
                        '-'
                      )}
                    </td>
                    <td>
                      <span className={`badge ${statusLabels[order.status]?.class || 'badge-default'}`}>
                        {statusLabels[order.status]?.label || order.status}
                      </span>
                    </td>
                    <td className="text-slate-400 text-sm">
                      {order.created_at ? new Date(order.created_at).toLocaleDateString('fa-IR') : '-'}
                    </td>
                    <td>
                      <button
                        onClick={() => setSelectedOrder(order)}
                        className="p-2 text-slate-400 hover:text-blue-500"
                        data-testid={`view-order-${order.id}`}
                      >
                        <Eye size={18} />
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

      {/* Order Detail Modal */}
      {selectedOrder && (
        <div className="modal-overlay" onClick={() => setSelectedOrder(null)}>
          <div className="modal-content p-6" onClick={(e) => e.stopPropagation()}>
            <h2 className="text-xl font-bold text-white mb-6">جزئیات سفارش</h2>
            <div className="space-y-4">
              <div className="flex justify-between">
                <span className="text-slate-400">شناسه:</span>
                <span className="font-mono text-blue-400">{selectedOrder.id}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-400">کاربر:</span>
                <span className="text-white">{selectedOrder.user?.first_name} (@{selectedOrder.user?.username})</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-400">پلن:</span>
                <span className="text-white">{selectedOrder.plan?.name}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-400">مبلغ اصلی:</span>
                <span className="font-mono">{formatPrice(selectedOrder.original_price || 0)}</span>
              </div>
              {selectedOrder.discount_amount > 0 && (
                <div className="flex justify-between">
                  <span className="text-slate-400">تخفیف:</span>
                  <span className="font-mono text-green-400">-{formatPrice(selectedOrder.discount_amount)}</span>
                </div>
              )}
              <div className="flex justify-between">
                <span className="text-slate-400">مبلغ نهایی:</span>
                <span className="font-mono text-lg">{formatPrice(selectedOrder.final_price || 0)}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-400">وضعیت:</span>
                <span className={`badge ${statusLabels[selectedOrder.status]?.class || 'badge-default'}`}>
                  {statusLabels[selectedOrder.status]?.label || selectedOrder.status}
                </span>
              </div>
            </div>
            <button onClick={() => setSelectedOrder(null)} className="btn-secondary w-full mt-6">
              بستن
            </button>
          </div>
        </div>
      )}
    </div>
  );
};

export default Orders;
