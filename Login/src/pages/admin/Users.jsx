import { useCallback, useEffect, useState } from "react";
import { usersApi } from "../../services/api";
import { getStoredUser } from "../../utils/auth";
import { Alert, Badge, Button, Field, Modal, PageHeader, inputCls } from "../../components/ui";

const empty = { name: "", email: "", password: "", role: "student" };

function Users() {
    const me = getStoredUser();
    const [users, setUsers] = useState([]);
    const [search, setSearch] = useState("");
    const [role, setRole] = useState("");
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState("");
    const [modal, setModal] = useState(null); // null | {id?, ...fields}
    const [formError, setFormError] = useState("");
    const [saving, setSaving] = useState(false);

    const load = useCallback(async () => {
        try {
            setError("");
            const d = await usersApi.list({ search, role });
            setUsers(d.users);
        } catch (e) {
            setError(e.message);
        } finally {
            setLoading(false);
        }
    }, [search, role]);

    useEffect(() => {
        const t = setTimeout(load, 250); // debounce search
        return () => clearTimeout(t);
    }, [load]);

    const save = async (e) => {
        e.preventDefault();
        setFormError("");
        setSaving(true);
        try {
            const { id, ...payload } = modal;
            if (id) await usersApi.update(id, payload);
            else await usersApi.create(payload);
            setModal(null);
            load();
        } catch (err) {
            setFormError(err.message);
        } finally {
            setSaving(false);
        }
    };

    const remove = async (u) => {
        if (!confirm(`Delete ${u.name}?`)) return;
        try {
            await usersApi.remove(u.id);
            load();
        } catch (err) {
            setError(err.message);
        }
    };

    const set = (k) => (e) => setModal({ ...modal, [k]: e.target.value });

    return (
        <div>
            <PageHeader title="Users" action={<Button onClick={() => { setFormError(""); setModal({ ...empty }); }}>+ Create User</Button>} />
            <Alert>{error}</Alert>

            <div className="flex gap-3 mb-4 flex-wrap">
                <input className={`${inputCls} max-w-xs`} placeholder="Search name or email" value={search} onChange={(e) => setSearch(e.target.value)} />
                <select className={`${inputCls} max-w-[160px]`} value={role} onChange={(e) => setRole(e.target.value)}>
                    <option value="">All roles</option>
                    <option value="admin">Admin</option>
                    <option value="staff">Staff</option>
                    <option value="student">Student</option>
                </select>
            </div>

            <div className="bg-white rounded-xl shadow overflow-x-auto">
                <table className="w-full text-left text-sm">
                    <thead className="bg-gray-50 text-gray-600">
                        <tr>
                            <th className="p-3">Name</th><th className="p-3">Email</th><th className="p-3">Role</th>
                            <th className="p-3">Created</th><th className="p-3 text-right">Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        {loading && <tr><td className="p-4" colSpan="5">Loading...</td></tr>}
                        {!loading && users.length === 0 && <tr><td className="p-4 text-gray-500" colSpan="5">No users found</td></tr>}
                        {users.map((u) => (
                            <tr key={u.id} className="border-t">
                                <td className="p-3 font-medium">{u.name}</td>
                                <td className="p-3">{u.email}</td>
                                <td className="p-3"><Badge>{u.role}</Badge></td>
                                <td className="p-3">{u.created_at?.slice(0, 10)}</td>
                                <td className="p-3 text-right whitespace-nowrap">
                                    <Button variant="ghost" className="mr-2 !py-1" onClick={() => { setFormError(""); setModal({ ...u, password: "" }); }}>Edit</Button>
                                    {u.id !== me?.id && <Button variant="danger" className="!py-1" onClick={() => remove(u)}>Delete</Button>}
                                </td>
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>

            {modal && (
                <Modal title={modal.id ? "Edit User" : "Create User"} onClose={() => setModal(null)}>
                    <Alert>{formError}</Alert>
                    <form onSubmit={save}>
                        <Field label="Name"><input className={inputCls} value={modal.name} onChange={set("name")} required /></Field>
                        <Field label="Email"><input type="email" className={inputCls} value={modal.email} onChange={set("email")} required /></Field>
                        <Field label="Role">
                            <select className={inputCls} value={modal.role} onChange={set("role")} disabled={modal.id === me?.id}>
                                <option value="student">Student</option>
                                <option value="staff">Staff</option>
                                <option value="admin">Admin</option>
                            </select>
                        </Field>
                        <Field label={modal.id ? "New password (leave blank to keep)" : "Password"}>
                            <input type="password" className={inputCls} value={modal.password} onChange={set("password")} minLength={6} required={!modal.id} />
                        </Field>
                        <div className="flex justify-end gap-2 mt-4">
                            <Button type="button" variant="ghost" onClick={() => setModal(null)}>Cancel</Button>
                            <Button disabled={saving}>{saving ? "Saving..." : "Save"}</Button>
                        </div>
                    </form>
                </Modal>
            )}
        </div>
    );
}

export default Users;
