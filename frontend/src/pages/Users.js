import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { Search, Ban, Wallet, RefreshCw } from 'lucide-react';
import toast from 'react-hot-toast';

const API_URL = process.env.REACT_APP_BACKEND_URL;

const formatPrice = (price) => {
  return new Intl.NumberFormat('fa-IR').format(price) + ' تومان';
};

const Users = () => {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState({ is_reseller: null, is_banned: null });
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(0);

  useEffect(() => {
    fetchUsers();
  }, [search, filter, page]);

  const fetchUsers = async () => {
    try {
      const params = new URLSearchParams();
      if (search) params.append('search', search);
      if (filter.is_reseller !== null) params.append('is_reseller', filter.is_reseller);
      if (filter.is_banned !== null) params.append('is_banned', filter.is_banned);
      params.append('skip', page * 50);
      params.append('limit', 50);

      const response = await axios.get(`${API_URL}/api/users?${params}`);
      setUsers(response.data.users);
      setTotal(response.data.total);
    } catch (error) {
      toast.error('خطا در دریافت کاربران');
    } finally {
      setLoading(false);
    }
  };

  const handleBan = async (telegramId) => {
    try {
      const response = await axios.put(`${API_URL}/api/users/${telegramId}/ban`);
      toast.success(response.data.is_banned ? 'کاربر مسدود شد' : 'کاربر آزاد شد');
      fetchUsers();
    } catch (error) {
      toast.error('خطا در تغییر وضعیت کاربر');
    }
  };

  const handleWalletUpdate = async (telegramId, currentBalance) => {
    const newAmount = prompt('موجودی جدید (تومان):', currentBalance);
    if (newAmount === null) return;

    try {
      await axios.put(`${API_URL}/api/users/${telegramId}/wallet?amount=${parseFloat(newAmount)}`);
      toast.success('موجودی بروزرسانی شد');
      fetchUsers();
    } catch (error) {
      toast.error('خطا در بروزرسانی موجودی');
    }
  };

  return (
    <div className="space-y-6" data-testid="users-page">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white">کاربران تلگرام</h1>
          <p className="text-slate-400 text-sm mt-1">{total} کاربر</p>
        </div>
        <button
          onClick={fetchUsers}
          className="btn-secondary flex items-center gap-2"
          data-testid="refresh-users-btn"
        >
          <RefreshCw size={18} />
          بروزرسانی
        </button>
      </div>

      {/* Filters */}
      <div className="glass-card p-4">
        <div className="flex flex-col sm:flex-row gap-4">
          <div className="flex-1 relative">
            <Search className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-500" size={18} />
            <input
              type="text"
              placeholder="جستجو (نام کاربری، شناسه)..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="input pr-10 w-full"
              data-testid="search-input"
            />
          </div>
          <select
            value={filter.is_reseller === null ? '' : filter.is_reseller.toString()}
            onChange={(e) => setFilter({ ...filter, is_reseller: e.target.value === '' ? null : e.target.value === 'true' })}
            className="input w-full sm:w-40"
            data-testid="reseller-filter"
          >
            <option value="">همه</option>
            <option value="true">نمایندگان</option>
            <option value="false">کاربران عادی</option>
          </select>
          <select
            value={filter.is_banned === null ? '' : filter.is_banned.toString()}
            onChange={(e) => setFilter({ ...filter, is_banned: e.target.value === '' ? null : e.target.value === 'true' })}
            className="input w-full sm:w-40"
            data-testid="banned-filter"
          >
            <option value="">همه</option>
            <option value="true">مسدود شده</option>
            <option value="false">فعال</option>
          </select>
        </div>
      </div>

      {/* Table */}
      <div className="glass-card overflow-hidden">
        <div className="overflow-x-auto">
          <table className="table">
            <thead>
              <tr>
                <th>شناسه تلگرام</th>
                <th>نام کاربری</th>
                <th>نام</th>
                <th>موجودی</th>
                <th>وضعیت</th>
                <th>نوع</th>
                <th>تاریخ عضویت</th>
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
              ) : users.length === 0 ? (
                <tr>
                  <td colSpan={8} className="text-center py-8 text-slate-400">
                    کاربری یافت نشد
                  </td>
                </tr>
              ) : (
                users.map((user) => (
                  <tr key={user.telegram_id} data-testid={`user-row-${user.telegram_id}`}>
                    <td className="font-mono text-blue-400">{user.telegram_id}</td>
                    <td>@{user.username || '-'}</td>
                    <td>{user.first_name || '-'} {user.last_name || ''}</td>
                    <td className="font-mono">{formatPrice(user.wallet_balance || 0)}</td>
                    <td>
                      <span className={`badge ${user.is_banned ? 'badge-error' : 'badge-success'}`}>
                        {user.is_banned ? 'مسدود' : 'فعال'}
                      </span>
                    </td>
                    <td>
                      {user.is_reseller && (
                        <span className="badge badge-info">نماینده</span>
                      )}
                    </td>
                    <td className="text-slate-400 text-sm">
                      {user.created_at ? new Date(user.created_at).toLocaleDateString('fa-IR') : '-'}
                    </td>
                    <td>
                      <div className="flex items-center gap-2">
                        <button
                          onClick={() => handleWalletUpdate(user.telegram_id, user.wallet_balance || 0)}
                          className="p-2 text-slate-400 hover:text-blue-500 transition-colors"
                          title="ویرایش موجودی"
                          data-testid={`wallet-btn-${user.telegram_id}`}
                        >
                          <Wallet size={18} />
                        </button>
                        <button
                          onClick={() => handleBan(user.telegram_id)}
                          className={`p-2 transition-colors ${user.is_banned ? 'text-green-500 hover:text-green-400' : 'text-slate-400 hover:text-red-500'}`}
                          title={user.is_banned ? 'رفع مسدودی' : 'مسدود کردن'}
                          data-testid={`ban-btn-${user.telegram_id}`}
                        >
                          <Ban size={18} />
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

      {/* Pagination */}
      {total > 50 && (
        <div className="flex justify-center gap-2">
          <button
            onClick={() => setPage(Math.max(0, page - 1))}
            disabled={page === 0}
            className="btn-secondary"
          >
            قبلی
          </button>
          <span className="px-4 py-2 text-slate-400">
            صفحه {page + 1} از {Math.ceil(total / 50)}
          </span>
          <button
            onClick={() => setPage(page + 1)}
            disabled={(page + 1) * 50 >= total}
            className="btn-secondary"
          >
            بعدی
          </button>
        </div>
      )}
    </div>
  );
};

export default Users;
