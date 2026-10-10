import { useCallback, useEffect, useState } from "react";
import { useSearchParams } from "react-router-dom";
import { staffApi } from "../../services/api";
import { Alert, Badge, Button, PageHeader, inputCls, todayStr } from "../../components/ui";

const OPTIONS = [
    ["present", "Present", "peer-checked:bg-green-600 peer-checked:text-white"],
    ["late", "Late", "peer-checked:bg-amber-500 peer-checked:text-white"],
    ["absent", "Absent", "peer-checked:bg-red-600 peer-checked:text-white"],
];

function StaffAttendance() {
    const [params, setParams] = useSearchParams();
    const [assignments, setAssignments] = useState([]);
    const [assignmentId, setAssignmentId] = useState(params.get("a") || "");
    const [date, setDate] = useState(todayStr());
    const [tab, setTab] = useState("mark"); // mark | report
    const [students, setStudents] = useState([]);
    const [marks, setMarks] = useState({});
    const [report, setReport] = useState([]);
    const [loading, setLoading] = useState(false);
    const [saving, setSaving] = useState(false);
    const [error, setError] = useState("");
    const [ok, setOk] = useState("");

    useEffect(() => {
        staffApi.dashboard().then((d) => {
            setAssignments(d.assignments);
            if (!assignmentId && d.assignments.length) setAssignmentId(String(d.assignments[0].id));
        }).catch((e) => setError(e.message));
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);

    const load = useCallback(async () => {
        if (!assignmentId) return;
        setLoading(true);
        setError("");
        try {
            if (tab === "mark") {
                const d = await staffApi.attendance(assignmentId, date);
                setStudents(d.students);
                const m = {};
                d.students.forEach((s) => { if (s.status) m[s.id] = s.status; });
                setMarks(m);
            } else {
                setReport((await staffApi.summary(assignmentId)).students);
            }
        } catch (e) {
            setError(e.message);
        } finally {
            setLoading(false);
        }
    }, [assignmentId, date, tab]);

    useEffect(() => { load(); }, [load]);

    const pick = (id) => (e) => { setOk(""); setMarks({ ...marks, [id]: e.target.value }); };
    const markAll = (status) => { setOk(""); const m = {}; students.forEach((s) => (m[s.id] = status)); setMarks(m); };

    const save = async () => {
        setError(""); setOk("");
        const missing = students.filter((s) => !marks[s.id]);
        if (missing.length) return setError(`Please mark all students (${missing.length} left)`);
        setSaving(true);
        try {
            const r = await staffApi.saveAttendance({
                assignment_id: Number(assignmentId),
                date,
                records: students.map((s) => ({ student_id: s.id, status: marks[s.id] })),
            });
            setOk(r.message);
        } catch (e) {
            setError(e.message);
        } finally {
            setSaving(false);
        }
    };

    const current = assignments.find((a) => String(a.id) === String(assignmentId));
    const counts = Object.values(marks).reduce((c, v) => ({ ...c, [v]: (c[v] || 0) + 1 }), {});

    return (
        <div>
            <PageHeader title="Attendance" />
            <Alert>{error}</Alert>
            <Alert type="success">{ok}</Alert>

            {assignments.length === 0 ? (
                <p className="text-gray-500 bg-white rounded-xl shadow p-4">No subject is assigned to you yet.</p>
            ) : (
                <>
                    <div className="flex gap-3 mb-4 flex-wrap items-end">
                        <label className="block">
                            <span className="block text-sm text-gray-600 mb-1">Subject / batch</span>
                            <select className={`${inputCls} min-w-[240px]`} value={assignmentId} onChange={(e) => { setAssignmentId(e.target.value); setParams({ a: e.target.value }); setOk(""); }}>
                                {assignments.map((a) => <option key={a.id} value={a.id}>{a.subject_name} — {a.batch_name}</option>)}
                            </select>
                        </label>
                        {tab === "mark" && (
                            <label className="block">
                                <span className="block text-sm text-gray-600 mb-1">Date</span>
                                <input type="date" className={inputCls} value={date} max={todayStr()} onChange={(e) => { setDate(e.target.value); setOk(""); }} />
                            </label>
                        )}
                        <div className="flex gap-1 ml-auto">
                            <Button variant={tab === "mark" ? "primary" : "ghost"} onClick={() => setTab("mark")}>Mark</Button>
                            <Button variant={tab === "report" ? "primary" : "ghost"} onClick={() => setTab("report")}>Report</Button>
                        </div>
                    </div>

                    {loading && <p>Loading...</p>}

                    {!loading && tab === "mark" && (
                        <>
                            {students.length === 0 ? (
                                <p className="text-gray-500 bg-white rounded-xl shadow p-4">No student has joined {current?.batch_name} yet.</p>
                            ) : (
                                <>
                                    <div className="flex gap-2 mb-3 flex-wrap items-center text-sm">
                                        <Button variant="ghost" className="!py-1" onClick={() => markAll("present")}>Mark all present</Button>
                                        <Button variant="ghost" className="!py-1" onClick={() => markAll("absent")}>Mark all absent</Button>
                                        <span className="text-gray-600 ml-2">
                                            Present {counts.present || 0} · Late {counts.late || 0} · Absent {counts.absent || 0}
                                        </span>
                                    </div>
                                    <div className="bg-white rounded-xl shadow divide-y">
                                        {students.map((s) => (
                                            <div key={s.id} className="p-3 flex items-center gap-3 flex-wrap">
                                                <div className="flex-1 min-w-[180px]">
                                                    <p className="font-medium">{s.name}</p>
                                                    <p className="text-xs text-gray-500">{s.email}</p>
                                                    {s.on_leave && <p className="text-xs text-amber-700 font-semibold mt-0.5">On approved leave today</p>}
                                                </div>
                                                <div className="flex gap-1">
                                                    {OPTIONS.map(([val, label, cls]) => (
                                                        <label key={val} className="cursor-pointer">
                                                            <input type="radio" className="peer sr-only" name={`att-${s.id}`} value={val} checked={marks[s.id] === val} onChange={pick(s.id)} />
                                                            <span className={`block px-3 py-1.5 rounded-lg border border-gray-300 text-sm ${cls}`}>{label}</span>
                                                        </label>
                                                    ))}
                                                </div>
                                            </div>
                                        ))}
                                    </div>
                                    <div className="mt-4">
                                        <Button onClick={save} disabled={saving} className="!px-6 !py-3">{saving ? "Saving..." : "Save attendance"}</Button>
                                    </div>
                                </>
                            )}
                        </>
                    )}

                    {!loading && tab === "report" && (
                        <div className="bg-white rounded-xl shadow overflow-x-auto">
                            <table className="w-full text-left text-sm">
                                <thead className="bg-gray-50 text-gray-600">
                                    <tr><th className="p-3">Student</th><th className="p-3">Present</th><th className="p-3">Late</th><th className="p-3">Absent</th><th className="p-3">Classes</th><th className="p-3">Attendance</th></tr>
                                </thead>
                                <tbody>
                                    {report.length === 0 && <tr><td className="p-4 text-gray-500" colSpan="6">No students</td></tr>}
                                    {report.map((r) => (
                                        <tr key={r.id} className="border-t">
                                            <td className="p-3 font-medium">{r.name}</td>
                                            <td className="p-3">{r.present}</td><td className="p-3">{r.late}</td><td className="p-3">{r.absent}</td>
                                            <td className="p-3">{r.total}</td>
                                            <td className="p-3">{r.percent === null ? "—" : <Badge>{r.percent >= 75 ? "present" : "absent"}</Badge>} {r.percent !== null && `${r.percent}%`}</td>
                                        </tr>
                                    ))}
                                </tbody>
                            </table>
                        </div>
                    )}
                </>
            )}
        </div>
    );
}

export default StaffAttendance;
