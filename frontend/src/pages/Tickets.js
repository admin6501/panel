import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { RefreshCw, MessageSquare, Send, Clock, CheckCircle, AlertCircle } from 'lucide-react';
import toast from 'react-hot-toast';

const API_URL = process.env.REACT_APP_BACKEND_URL;

const statusLabels = {
  open: { label: 'باز', class: 'badge-success', icon: AlertCircle },
  answered: { label: 'پاسخ داده شده', class: 'badge-info', icon: CheckCircle },
  waiting: { label: 'در انتظار', class: 'badge-warning', icon: Clock },
  closed: { label: 'بسته', class: 'badge-default', icon: CheckCircle }
};

const Tickets = () => {
  const [tickets, setTickets] = useState([]);
  const [departments, setDepartments] = useState([]);
  const [loading, setLoading] = useState(true);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(0);
  const [statusFilter, setStatusFilter] = useState('');
  const [deptFilter, setDeptFilter] = useState('');
  const [selectedTicket, setSelectedTicket] = useState(null);
  const [replyMessage, setReplyMessage] = useState('');
  const [sending, setSending] = useState(false);

  useEffect(() => {
    fetchData();
  }, [page, statusFilter, deptFilter]);

  const fetchData = async () => {
    try {
      const [ticketsRes, deptsRes] = await Promise.all([
        axios.get(`${API_URL}/api/tickets`, {
          params: {
            status: statusFilter || undefined,
            department_id: deptFilter || undefined,
            skip: page * 50,
            limit: 50
          }
        }),
        axios.get(`${API_URL}/api/departments`)
      ]);
      setTickets(ticketsRes.data.tickets);
      setTotal(ticketsRes.data.total);
      setDepartments(deptsRes.data);
    } catch (error) {
      toast.error('خطا در دریافت تیکت‌ها');
    } finally {
      setLoading(false);
    }
  };

  const handleViewTicket = async (ticketId) => {
    try {
      const response = await axios.get(`${API_URL}/api/tickets/${ticketId}`);
      setSelectedTicket(response.data);
    } catch (error) {
      toast.error('خطا در دریافت تیکت');
    }
  };

  const handleReply = async () => {
    if (!replyMessage.trim() || !selectedTicket) return;
    setSending(true);
    try {
      await axios.post(`${API_URL}/api/tickets/${selectedTicket.id}/reply`, {
        message: replyMessage
      });
      toast.success('پاسخ ارسال شد');
      setReplyMessage('');
      handleViewTicket(selectedTicket.id);
      fetchData();
    } catch (error) {
      toast.error('خطا در ارسال پاسخ');
    } finally {
      setSending(false);
    }
  };

  const handleStatusChange = async (status) => {
    if (!selectedTicket) return;
    try {
      await axios.put(`${API_URL}/api/tickets/${selectedTicket.id}`, { status });
      toast.success('وضعیت تغییر کرد');
      handleViewTicket(selectedTicket.id);
      fetchData();
    } catch (error) {
      toast.error('خطا در تغییر وضعیت');
    }
  };

  return (
    <div className="space-y-6" data-testid="tickets-page">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white">تیکت‌های پشتیبانی</h1>
          <p className="text-slate-400 text-sm mt-1">{total} تیکت</p>
        </div>
        <div className="flex flex-wrap gap-2">
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="input w-36"
            data-testid="ticket-status-filter"
          >
            <option value="">همه وضعیت‌ها</option>
            <option value="open">باز</option>
            <option value="answered">پاسخ داده شده</option>
            <option value="waiting">در انتظار</option>
            <option value="closed">بسته</option>
          </select>
          <select
            value={deptFilter}
            onChange={(e) => setDeptFilter(e.target.value)}
            className="input w-40"
            data-testid="ticket-dept-filter"
          >
            <option value="">همه دپارتمان‌ها</option>
            {departments.map((dept) => (
              <option key={dept.id} value={dept.id}>{dept.name}</option>
            ))}
          </select>
          <button onClick={fetchData} className="btn-secondary">
            <RefreshCw size={18} />
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Tickets List */}
        <div className="lg:col-span-1 glass-card overflow-hidden">
          <div className="p-4 border-b border-[#1e293b]">
            <h3 className="font-semibold text-white">لیست تیکت‌ها</h3>
          </div>
          <div className="max-h-[600px] overflow-y-auto">
            {loading ? (
              <div className="flex justify-center py-8">
                <div className="spinner"></div>
              </div>
            ) : tickets.length === 0 ? (
              <div className="text-center py-8 text-slate-400">تیکتی یافت نشد</div>
            ) : (
              tickets.map((ticket) => {
                const StatusIcon = statusLabels[ticket.status]?.icon || AlertCircle;
                return (
                  <div
                    key={ticket.id}
                    onClick={() => handleViewTicket(ticket.id)}
                    className={`p-4 border-b border-[#1e293b] cursor-pointer transition-colors hover:bg-[#1e293b]/50 ${
                      selectedTicket?.id === ticket.id ? 'bg-blue-500/10 border-r-2 border-r-blue-500' : ''
                    }`}
                    data-testid={`ticket-item-${ticket.id}`}
                  >
                    <div className="flex items-start justify-between mb-2">
                      <h4 className="font-medium text-white text-sm truncate flex-1">{ticket.subject}</h4>
                      <StatusIcon size={16} className={`${
                        ticket.status === 'open' ? 'text-green-500' :
                        ticket.status === 'waiting' ? 'text-amber-500' :
                        ticket.status === 'answered' ? 'text-blue-500' : 'text-slate-500'
                      }`} />
                    </div>
                    <div className="flex items-center justify-between text-xs text-slate-500">
                      <span>{ticket.department?.name}</span>
                      <span>{ticket.user?.first_name || ticket.user?.username}</span>
                    </div>
                  </div>
                );
              })
            )}
          </div>
        </div>

        {/* Ticket Detail */}
        <div className="lg:col-span-2 glass-card">
          {!selectedTicket ? (
            <div className="flex flex-col items-center justify-center h-96 text-slate-400">
              <MessageSquare size={48} className="mb-4" />
              <p>یک تیکت را انتخاب کنید</p>
            </div>
          ) : (
            <div className="flex flex-col h-[600px]">
              {/* Header */}
              <div className="p-4 border-b border-[#1e293b]">
                <div className="flex items-start justify-between">
                  <div>
                    <h3 className="font-semibold text-white">{selectedTicket.subject}</h3>
                    <p className="text-sm text-slate-400 mt-1">
                      {selectedTicket.user?.first_name} (@{selectedTicket.user?.username}) • {selectedTicket.department?.name}
                    </p>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className={`badge ${statusLabels[selectedTicket.status]?.class}`}>
                      {statusLabels[selectedTicket.status]?.label}
                    </span>
                    {selectedTicket.status !== 'closed' && (
                      <button
                        onClick={() => handleStatusChange('closed')}
                        className="btn-secondary text-xs"
                      >
                        بستن تیکت
                      </button>
                    )}
                  </div>
                </div>
              </div>

              {/* Messages */}
              <div className="flex-1 overflow-y-auto p-4 space-y-4">
                {selectedTicket.messages?.map((msg) => (
                  <div
                    key={msg.id}
                    className={`flex ${msg.is_admin ? 'justify-start' : 'justify-end'}`}
                  >
                    <div
                      className={`max-w-[80%] p-3 rounded-lg ${
                        msg.is_admin
                          ? 'bg-blue-500/10 border border-blue-500/20'
                          : 'bg-slate-800 border border-slate-700'
                      }`}
                    >
                      <p className="text-sm text-white whitespace-pre-wrap">{msg.message}</p>
                      <div className="flex items-center justify-between mt-2 text-xs text-slate-500">
                        <span>{msg.is_admin ? `${msg.admin_username || 'پشتیبانی'}` : 'کاربر'}</span>
                        <span>{msg.created_at ? new Date(msg.created_at).toLocaleString('fa-IR') : ''}</span>
                      </div>
                    </div>
                  </div>
                ))}
              </div>

              {/* Reply */}
              {selectedTicket.status !== 'closed' && (
                <div className="p-4 border-t border-[#1e293b]">
                  <div className="flex gap-2">
                    <textarea
                      value={replyMessage}
                      onChange={(e) => setReplyMessage(e.target.value)}
                      className="input flex-1 min-h-[60px]"
                      placeholder="پاسخ خود را بنویسید..."
                      data-testid="ticket-reply-input"
                    />
                    <button
                      onClick={handleReply}
                      disabled={sending || !replyMessage.trim()}
                      className="btn-primary"
                      data-testid="send-reply-btn"
                    >
                      <Send size={18} />
                    </button>
                  </div>
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default Tickets;
