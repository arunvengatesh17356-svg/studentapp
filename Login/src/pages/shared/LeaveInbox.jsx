import { useCallback, useEffect, useState } from "react";
import { leavesApi } from "../../services/api";
import { getStoredUser } from "../../utils/auth";
import { Alert, Badge, Button, Field, Modal, PageHeader, formatDate, inputCls } from "../../components/ui";

/*
| Leave requests waiting for a decision.
|   admin -> student + staff leaves
|   staff -> leaves of students in the batches they handle
*/
function LeaveInbox() {
    const isAdmin = getStoredUser()?.role === "admin";
    const [rows, setRows] = useState([]);
    const [filter, setFilter] = useState({ status: "pending", role: "" });
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState("");
    const [ok, setOk] = useState("");
    const [modal, setModal] = useState(null); // { leave, status, note }
    const [saving, setSaving] = useState(false);

    const load = useCallback(async () => {
        try {
            setError("");
            setRows((await leavesApi.inbox(filter)).leaves);
        } catch (e) {
            setError(e.message);
        } finally {
            setLoading(false);
        }
    }, [filter]);

    useEffect(() => { load(); }, [load]);

    const submit = async (e) => {
        e.preventDefault();
        setSaving(true);
        try {
            await leavesApi.review(modal.leave.id, { status: modal.status, note: modal.note });
            setOk(`Leave ${modal.status}`);
            setModal(null);
            load();
        } catch (err) {
            setError(err.message);
            setModal(null);
        } finally {
            setSaving(false);
        }
    };

    const f = (k) => (e) => setFilter({ ...filter, [k]: e.target.value });

    return (
        <div>
            <PageHeader title={isAdmin ? "Leave Requests" : "Student Leave Requests"} />
            <Alert>{error}</Alert>
            <Alert type="success">{ok}</Alert>

            <div className="flex gap-3 mb-4 flex-wrap">
                <select className={`${inputCls} max-w-[180px]`} value={filter.status} onChange={f("status")}>
                    <option value="pending">Pending</option>
                    <option value="approved">Approved</option>
                    <option value="rejected">Rejected</option>
                    <option value="cancelled">Cancelled</option>
                    <option value="">All</option>
                </select>
                {isAdmin && (
                    <select className={`${inputCls} max-w-[180px]`} value={filter.role} onChange={f("role")}>
                        <option value="">Students & staff</option>
                        <option value="student">Students</option>
                        <option value="staff">Staff</option>
                    </select>
                )}
            </div>

            <div className="bg-white rounded-xl shadow overflow-x-auto">
                <table className="w-full text-left text-sm">
                    <thead className="bg-gray-50 text-gray-600">
                        <tr>
                            <th className="p-3">Requested by</th><th className="p-3">Batch</th><th className="p-3">Dates</th>
                            <th className="p-3">Reason</th><th className="p-3">Status</th><th className="p-3 text-right">Action</th>
                        </tr>
                    </thead>
                    <tbody>
                        {loading && <tr><td className="p-4" colSpan="6">Loading...</td></tr>}
                        {!loading && rows.length === 0 && <tr><td className="p-4 text-gray-500" colSpan="6">No leave requests</td></tr>}
                        {rows.map((l) => (
                            <tr key={l.id} className="border-t align-top">
                                <td className="p-3 font-medium">{l.requester_name} <Badge>{l.user_role}</Badge><br /><span className="text-xs text-gray-500 font-normal">{l.requester_email}</span></td>
                                <td className="p-3">{l.batch_name ? <>{l.batch_name}<br /><span className="text-xs text-gray-500">{l.course_name}</span></> : "—"}</td>
                                <td className="p-3 whitespace-nowrap">{formatDate(l.from_date)}{l.to_date !== l.from_date && <> → {formatDate(l.to_date)}</>}</td>
                                <td className="p-3 max-w-xs whitespace-pre-line">{l.reason}</td>
                                <td className="p-3">
                                    <Badge>{l.status}</Badge>
                                    {l.reviewed_by_name && <p className="text-xs text-gray-500 mt-1">by {l.reviewed_by_name}</p>}
                                    {l.review_note && <p className="text-xs text-gray-500">“{l.review_note}”</p>}
                                </td>
                                <td className="p-3 text-right whitespace-nowrap">
                                    {l.status === "pending" && (
                                        <>
                                            <Button className="mr-2 !py-1 !bg-green-600 hover:!bg-green-700" onClick={() => setModal({ leave: l, status: "approved", note: "" })}>Approve</Button>
                                            <Button variant="danger" className="!py-1" onClick={() => setModal({ leave: l, status: "rejected", note: "" })}>Reject</Button>
                                        </>
                                    )}
                                </td>
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>

            {modal && (
                <Modal title={`${modal.status === "approved" ? "Approve" : "Reject"} leave — ${modal.leave.requester_name}`} onClose={() => setModal(null)}>
                    <form onSubmit={submit}>
                        <Field label="Note (optional)">
                            <textarea className={inputCls} rows="3" maxLength={500} value={modal.note} onChange={(e) => setModal({ ...modal, note: e.target.value })} />
                        </Field>
                        <div className="flex justify-end gap-2 mt-4">
                            <Button type="button" variant="ghost" onClick={() => setModal(null)}>Cancel</Button>
                            <Button variant={modal.status === "approved" ? "primary" : "danger"} disabled={saving}>{saving ? "Saving..." : `Confirm ${modal.status === "approved" ? "approval" : "rejection"}`}</Button>
                        </div>
                    </form>
                </Modal>
            )}
        </div>
    );
}

export default LeaveInbox;
