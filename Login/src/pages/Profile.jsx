import { useEffect, useState } from "react";
import { profileApi } from "../services/api";
import { getStoredUser, saveUser } from "../utils/auth";
import { Alert, Badge, Button, Field, PageHeader, inputCls } from "../components/ui";

function Profile() {
    const [form, setForm] = useState({ name: "", email: "" });
    const [role, setRole] = useState(getStoredUser()?.role || "");
    const [pw, setPw] = useState({ current_password: "", new_password: "", confirm: "" });
    const [msg, setMsg] = useState({ type: "", text: "" });
    const [pwMsg, setPwMsg] = useState({ type: "", text: "" });
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        profileApi.get()
            .then((d) => { setForm({ name: d.user.name, email: d.user.email }); setRole(d.user.role); })
            .catch((e) => setMsg({ type: "error", text: e.message }))
            .finally(() => setLoading(false));
    }, []);

    const saveProfile = async (e) => {
        e.preventDefault();
        setMsg({ type: "", text: "" });
        try {
            const d = await profileApi.update(form);
            saveUser({ id: d.user.id, name: d.user.name, email: d.user.email, role: d.user.role });
            setMsg({ type: "success", text: "Profile updated" });
        } catch (err) {
            setMsg({ type: "error", text: err.message });
        }
    };

    const savePassword = async (e) => {
        e.preventDefault();
        setPwMsg({ type: "", text: "" });
        if (pw.new_password !== pw.confirm) return setPwMsg({ type: "error", text: "Passwords do not match" });
        try {
            await profileApi.changePassword({ current_password: pw.current_password, new_password: pw.new_password });
            setPw({ current_password: "", new_password: "", confirm: "" });
            setPwMsg({ type: "success", text: "Password changed" });
        } catch (err) {
            setPwMsg({ type: "error", text: err.message });
        }
    };

    if (loading) return <p>Loading...</p>;

    return (
        <div className="max-w-xl">
            <PageHeader title="My Profile" />

            <form onSubmit={saveProfile} className="bg-white rounded-xl shadow p-6 mb-6">
                <div className="flex items-center justify-between mb-4">
                    <h2 className="font-semibold text-lg">Details</h2>
                    <Badge>{role}</Badge>
                </div>
                <Alert type={msg.type}>{msg.text}</Alert>
                <Field label="Name"><input className={inputCls} value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required /></Field>
                <Field label="Email"><input type="email" className={inputCls} value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} required /></Field>
                <Button>Save changes</Button>
            </form>

            <form onSubmit={savePassword} className="bg-white rounded-xl shadow p-6">
                <h2 className="font-semibold text-lg mb-4">Change password</h2>
                <Alert type={pwMsg.type}>{pwMsg.text}</Alert>
                <Field label="Current password"><input type="password" className={inputCls} value={pw.current_password} onChange={(e) => setPw({ ...pw, current_password: e.target.value })} required /></Field>
                <Field label="New password"><input type="password" minLength={6} className={inputCls} value={pw.new_password} onChange={(e) => setPw({ ...pw, new_password: e.target.value })} required /></Field>
                <Field label="Confirm new password"><input type="password" minLength={6} className={inputCls} value={pw.confirm} onChange={(e) => setPw({ ...pw, confirm: e.target.value })} required /></Field>
                <Button>Update password</Button>
            </form>
        </div>
    );
}

export default Profile;
