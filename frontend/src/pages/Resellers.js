import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { Plus, Edit2, Trash2, UserCheck, RefreshCw, Wallet } from 'lucide-react';
import toast from 'react-hot-toast';

const API_URL = process.env.REACT_APP_BACKEND_URL;

const formatPrice = (price) => {
  return new Intl.NumberFormat('fa-IR').format(price) + ' تومان';
};

const Resellers = () => {
  const [resellers, setResellers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [editingReseller, setEditingReseller] = useState(null);
  const [formData, setFormData] = useState({
    telegram_user_id: '',
    discount_percent: '10',
    credit_limit: '0',
    is_active: true
  });

  useEffect(() => {
    fetchResellers();
  }, []);

  const fetchResellers = async () => {
    try {
      const response = await axios.get(`${API_URL}/api/resellers`);
      setResellers(response.data);
    } catch (error) {
      toast.error('خطا در دریافت نمایندگان');
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      const data = {
        ...formData,
        telegram_user_id: parseInt(formData.telegram_user_id),
        discount_percent: parseFloat(formData.discount_percent),
        credit_limit: parseFloat(formData.credit_limit)
      };

      if (editingReseller) {
        await axios.put(`${API_URL}/api/resellers/${editingReseller.id}`, data);
        toast.success('نماینده بروزرسانی شد');
      } else {
        await axios.post(`${API_URL}/api/resellers`, data);
        toast.success('نماینده اضافه شد');
      }
      setShowModal(false);
      resetForm();
      fetchResellers();
    } catch (error) {
      toast.error(error.response?.data?.detail || 'خطا در ذخیره نماینده');
    }
  };

  const handleDelete = async (id) => {
    if (!window.confirm('آیا از حذف این نماینده اطمینان دارید؟')) return;
    try {
      await axios.delete(`${API_URL}/api/resellers/${id}`);
      toast.success('نماینده حذف شد');
      fetchResellers();
    } catch (error) {
      toast.error('خطا در حذف نماینده');
    }
  };

  const openEditModal = (reseller) => {
    setEditingReseller(reseller);
    setFormData({
      telegram_user_id: reseller.telegram_user_id.toString(),
      discount_percent: reseller.discount_percent.toString(),
      credit_limit: reseller.credit_limit?.toString() || '0',
      is_active: reseller.is_active
    });
    setShowModal(true);
  };

  const resetForm = () => {
    setEditingReseller(null);
    setFormData({
      telegram_user_id: '',
      discount_percent: '10',
      credit_limit: '0',
      is_active: true
    });
  };

  const handleBalanceUpdate = async (resellerId, currentBalance) => {
    const newAmount = prompt('موجودی جدید (تومان):', currentBalance);
    if (newAmount === null) return;

    try {
      await axios.put(`${API_URL}/api/resellers/${resellerId}`, {
        balance: parseFloat(newAmount)
      });
      toast.success('موجودی بروزرسانی شد');
      fetchResellers();
    } catch (error) {
      toast.error('خطا در بروزرسانی موجودی');
    }
  };

  return (
    <div className="space-y-6" data-testid="resellers-page">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white">نمایندگان</h1>
          <p className="text-slate-400 text-sm mt-1">{resellers.length} نماینده</p>
        </div>
        <div className="flex gap-2">
          <button onClick={fetchResellers} className="btn-secondary">
            <RefreshCw size={18} />
          </button>
          <button
            onClick={() => { resetForm(); setShowModal(true); }}
            className="btn-primary flex items-center gap-2"
            data-testid="add-reseller-btn"
          >
            <Plus size={18} />
            افزودن نماینده
          </button>
        </div>
      </div>

      {/* Info Card */}
      <div className="glass-card p-4 border-blue-500/30 bg-blue-500/5">
        <div className="flex items-center gap-3">
          <UserCheck className="text-blue-500" size={24} />
          <div>
            <p className="text-blue-400 font-medium">سیستم نمایندگی</p>
            <p className="text-sm text-slate-400">نمایندگان می‌توانند با تخفیف اختصاصی از ربات خرید کنند</p>
          </div>
        </div>
      </div>

      {/* Table */}
      <div className="glass-card overflow-hidden">
        <div className="overflow-x-auto">
          <table className="table">
            <thead>
              <tr>
                <th>کاربر</th>
                <th>شناسه تلگرام</th>
                <th>تخفیف</th>
                <th>موجودی</th>
                <th>اعتبار</th>
                <th>فروش کل</th>
                <th>وضعیت</th>
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
              ) : resellers.length === 0 ? (
                <tr>
                  <td colSpan={8} className="text-center py-8 text-slate-400">
                    نماینده‌ای یافت نشد
                  </td>
                </tr>
              ) : (
                resellers.map((reseller) => (
                  <tr key={reseller.id} data-testid={`reseller-row-${reseller.id}`}>
                    <td>
                      <div>
                        <p className="text-white">{reseller.user?.first_name || '-'}</p>
                        <p className="text-xs text-slate-500">@{reseller.user?.username || '-'}</p>
                      </div>
                    </td>
                    <td className="font-mono text-blue-400">{reseller.telegram_user_id}</td>
                    <td>
                      <span className="text-green-400 font-medium">{reseller.discount_percent}%</span>
                    </td>
                    <td className="font-mono">{formatPrice(reseller.balance || 0)}</td>
                    <td className="font-mono">{formatPrice(reseller.credit_limit || 0)}</td>
                    <td className="font-mono">{reseller.total_sales || 0}</td>
                    <td>
                      <span className={`badge ${reseller.is_active ? 'badge-success' : 'badge-default'}`}>
                        {reseller.is_active ? 'فعال' : 'غیرفعال'}
                      </span>
                    </td>
                    <td>
                      <div className="flex items-center gap-2">
                        <button
                          onClick={() => handleBalanceUpdate(reseller.id, reseller.balance || 0)}
                          className="p-2 text-slate-400 hover:text-green-500"
                          title="ویرایش موجودی"
                          data-testid={`reseller-balance-${reseller.id}`}
                        >
                          <Wallet size={18} />
                        </button>
                        <button
                          onClick={() => openEditModal(reseller)}
                          className="p-2 text-slate-400 hover:text-blue-500"
                          data-testid={`edit-reseller-${reseller.id}`}
                        >
                          <Edit2 size={18} />
                        </button>
                        <button
                          onClick={() => handleDelete(reseller.id)}
                          className="p-2 text-slate-400 hover:text-red-500"
                          data-testid={`delete-reseller-${reseller.id}`}
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
              {editingReseller ? 'ویرایش نماینده' : 'افزودن نماینده'}
            </h2>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label className="block text-sm text-slate-400 mb-2">شناسه تلگرام کاربر</label>
                <input
                  type="number"
                  value={formData.telegram_user_id}
                  onChange={(e) => setFormData({ ...formData, telegram_user_id: e.target.value })}
                  className="input"
                  placeholder="123456789"
                  required
                  disabled={!!editingReseller}
                  data-testid="reseller-userid-input"
                />
                <p className="text-xs text-slate-500 mt-1">کاربر باید قبلاً ربات را استارت کرده باشد</p>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm text-slate-400 mb-2">درصد تخفیف</label>
                  <input
                    type="number"
                    value={formData.discount_percent}
                    onChange={(e) => setFormData({ ...formData, discount_percent: e.target.value })}
                    className="input"
                    placeholder="10"
                    min="0"
                    max="100"
                    required
                    data-testid="reseller-discount-input"
                  />
                </div>
                <div>
                  <label className="block text-sm text-slate-400 mb-2">سقف اعتبار (تومان)</label>
                  <input
                    type="number"
                    value={formData.credit_limit}
                    onChange={(e) => setFormData({ ...formData, credit_limit: e.target.value })}
                    className="input"
                    placeholder="0"
                    data-testid="reseller-credit-input"
                  />
                </div>
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
                <button type="submit" className="btn-primary flex-1" data-testid="save-reseller-btn">
                  {editingReseller ? 'بروزرسانی' : 'افزودن'}
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

export default Resellers;
