import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { Plus, Edit2, Trash2, Tag, RefreshCw, Copy } from 'lucide-react';
import toast from 'react-hot-toast';

const API_URL = process.env.REACT_APP_BACKEND_URL;

const formatPrice = (price) => {
  return new Intl.NumberFormat('fa-IR').format(price) + ' تومان';
};

const DiscountCodes = () => {
  const [codes, setCodes] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [editingCode, setEditingCode] = useState(null);
  const [formData, setFormData] = useState({
    code: '',
    discount_percent: '',
    discount_amount: '',
    max_uses: '',
    valid_until: '',
    min_order_amount: '',
    is_active: true
  });

  useEffect(() => {
    fetchCodes();
  }, []);

  const fetchCodes = async () => {
    try {
      const response = await axios.get(`${API_URL}/api/discount-codes`);
      setCodes(response.data);
    } catch (error) {
      toast.error('خطا در دریافت کدها');
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      const data = {
        ...formData,
        discount_percent: formData.discount_percent ? parseFloat(formData.discount_percent) : null,
        discount_amount: formData.discount_amount ? parseFloat(formData.discount_amount) : null,
        max_uses: formData.max_uses ? parseInt(formData.max_uses) : null,
        min_order_amount: formData.min_order_amount ? parseFloat(formData.min_order_amount) : null,
        valid_until: formData.valid_until ? new Date(formData.valid_until).toISOString() : null
      };

      if (editingCode) {
        await axios.put(`${API_URL}/api/discount-codes/${editingCode.id}`, data);
        toast.success('کد بروزرسانی شد');
      } else {
        await axios.post(`${API_URL}/api/discount-codes`, data);
        toast.success('کد اضافه شد');
      }
      setShowModal(false);
      resetForm();
      fetchCodes();
    } catch (error) {
      toast.error(error.response?.data?.detail || 'خطا در ذخیره کد');
    }
  };

  const handleDelete = async (id) => {
    if (!window.confirm('آیا از حذف این کد اطمینان دارید؟')) return;
    try {
      await axios.delete(`${API_URL}/api/discount-codes/${id}`);
      toast.success('کد حذف شد');
      fetchCodes();
    } catch (error) {
      toast.error('خطا در حذف کد');
    }
  };

  const copyCode = (code) => {
    navigator.clipboard.writeText(code);
    toast.success('کد کپی شد');
  };

  const openEditModal = (code) => {
    setEditingCode(code);
    setFormData({
      code: code.code,
      discount_percent: code.discount_percent?.toString() || '',
      discount_amount: code.discount_amount?.toString() || '',
      max_uses: code.max_uses?.toString() || '',
      valid_until: code.valid_until ? code.valid_until.slice(0, 10) : '',
      min_order_amount: code.min_order_amount?.toString() || '',
      is_active: code.is_active
    });
    setShowModal(true);
  };

  const resetForm = () => {
    setEditingCode(null);
    setFormData({
      code: '',
      discount_percent: '',
      discount_amount: '',
      max_uses: '',
      valid_until: '',
      min_order_amount: '',
      is_active: true
    });
  };

  const generateCode = () => {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    let result = '';
    for (let i = 0; i < 8; i++) {
      result += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    setFormData({ ...formData, code: result });
  };

  return (
    <div className="space-y-6" data-testid="discount-codes-page">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white">کدهای تخفیف</h1>
          <p className="text-slate-400 text-sm mt-1">{codes.length} کد</p>
        </div>
        <div className="flex gap-2">
          <button onClick={fetchCodes} className="btn-secondary">
            <RefreshCw size={18} />
          </button>
          <button
            onClick={() => { resetForm(); setShowModal(true); }}
            className="btn-primary flex items-center gap-2"
            data-testid="add-discount-btn"
          >
            <Plus size={18} />
            افزودن کد
          </button>
        </div>
      </div>

      {/* Table */}
      <div className="glass-card overflow-hidden">
        <div className="overflow-x-auto">
          <table className="table">
            <thead>
              <tr>
                <th>کد</th>
                <th>تخفیف</th>
                <th>استفاده</th>
                <th>انقضا</th>
                <th>وضعیت</th>
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
              ) : codes.length === 0 ? (
                <tr>
                  <td colSpan={6} className="text-center py-8 text-slate-400">
                    کدی یافت نشد
                  </td>
                </tr>
              ) : (
                codes.map((code) => (
                  <tr key={code.id} data-testid={`discount-row-${code.id}`}>
                    <td>
                      <div className="flex items-center gap-2">
                        <span className="font-mono text-blue-400 bg-blue-500/10 px-2 py-1 rounded">{code.code}</span>
                        <button onClick={() => copyCode(code.code)} className="text-slate-500 hover:text-white">
                          <Copy size={14} />
                        </button>
                      </div>
                    </td>
                    <td>
                      {code.discount_percent ? (
                        <span className="text-green-400">{code.discount_percent}%</span>
                      ) : code.discount_amount ? (
                        <span className="text-green-400">{formatPrice(code.discount_amount)}</span>
                      ) : '-'}
                    </td>
                    <td>
                      <span className="text-white">{code.used_count || 0}</span>
                      {code.max_uses && <span className="text-slate-500"> / {code.max_uses}</span>}
                    </td>
                    <td className="text-slate-400 text-sm">
                      {code.valid_until ? new Date(code.valid_until).toLocaleDateString('fa-IR') : 'بدون انقضا'}
                    </td>
                    <td>
                      <span className={`badge ${code.is_active ? 'badge-success' : 'badge-default'}`}>
                        {code.is_active ? 'فعال' : 'غیرفعال'}
                      </span>
                    </td>
                    <td>
                      <div className="flex items-center gap-2">
                        <button
                          onClick={() => openEditModal(code)}
                          className="p-2 text-slate-400 hover:text-blue-500"
                          data-testid={`edit-discount-${code.id}`}
                        >
                          <Edit2 size={18} />
                        </button>
                        <button
                          onClick={() => handleDelete(code.id)}
                          className="p-2 text-slate-400 hover:text-red-500"
                          data-testid={`delete-discount-${code.id}`}
                        >
                          <Trash2 size={18} />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Modal */}
      {showModal && (
        <div className="modal-overlay" onClick={() => setShowModal(false)}>
          <div className="modal-content p-6" onClick={(e) => e.stopPropagation()}>
            <h2 className="text-xl font-bold text-white mb-6">
              {editingCode ? 'ویرایش کد تخفیف' : 'افزودن کد تخفیف'}
            </h2>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label className="block text-sm text-slate-400 mb-2">کد</label>
                <div className="flex gap-2">
                  <input
                    type="text"
                    value={formData.code}
                    onChange={(e) => setFormData({ ...formData, code: e.target.value.toUpperCase() })}
                    className="input flex-1 font-mono"
                    placeholder="DISCOUNT20"
                    required
                    data-testid="discount-code-input"
                  />
                  <button type="button" onClick={generateCode} className="btn-secondary">
                    تولید
                  </button>
                </div>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm text-slate-400 mb-2">تخفیف درصدی</label>
                  <input
                    type="number"
                    value={formData.discount_percent}
                    onChange={(e) => setFormData({ ...formData, discount_percent: e.target.value, discount_amount: '' })}
                    className="input"
                    placeholder="20"
                    min="0"
                    max="100"
                    data-testid="discount-percent-input"
                  />
                </div>
                <div>
                  <label className="block text-sm text-slate-400 mb-2">تخفیف مبلغی (تومان)</label>
                  <input
                    type="number"
                    value={formData.discount_amount}
                    onChange={(e) => setFormData({ ...formData, discount_amount: e.target.value, discount_percent: '' })}
                    className="input"
                    placeholder="10000"
                    data-testid="discount-amount-input"
                  />
                </div>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm text-slate-400 mb-2">حداکثر استفاده</label>
                  <input
                    type="number"
                    value={formData.max_uses}
                    onChange={(e) => setFormData({ ...formData, max_uses: e.target.value })}
                    className="input"
                    placeholder="نامحدود"
                  />
                </div>
                <div>
                  <label className="block text-sm text-slate-400 mb-2">تاریخ انقضا</label>
                  <input
                    type="date"
                    value={formData.valid_until}
                    onChange={(e) => setFormData({ ...formData, valid_until: e.target.value })}
                    className="input"
                  />
                </div>
              </div>
              <div>
                <label className="block text-sm text-slate-400 mb-2">حداقل مبلغ سفارش</label>
                <input
                  type="number"
                  value={formData.min_order_amount}
                  onChange={(e) => setFormData({ ...formData, min_order_amount: e.target.value })}
                  className="input"
                  placeholder="بدون محدودیت"
                />
              </div>
              <div className="flex items-center gap-2">
                <input
                  type="checkbox"
                  id="is_active"
                  checked={formData.is_active}
                  onChange={(e) => setFormData({ ...formData, is_active: e.target.checked })}
                  className="w-4 h-4"
                />
                <label htmlFor="is_active" className="text-sm text-slate-300">فعال</label>
              </div>
              <div className="flex gap-3 pt-4">
                <button type="submit" className="btn-primary flex-1" data-testid="save-discount-btn">
                  {editingCode ? 'بروزرسانی' : 'افزودن'}
                </button>
                <button type="button" onClick={() => setShowModal(false)} className="btn-secondary">
                  انصراف
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default DiscountCodes;
