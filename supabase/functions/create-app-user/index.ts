
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });
  const auth = req.headers.get("Authorization");
  if (!auth) return new Response("Unauthorized", { status: 401 });

  const url = Deno.env.get("SUPABASE_URL")!;
  const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const userClient = createClient(url, anon, { global: { headers: { Authorization: auth } } });
  const admin = createClient(url, service);

  const { data: { user } } = await userClient.auth.getUser();
  if (!user) return new Response("Unauthorized", { status: 401 });

  const { data: owner } = await admin.from("profiles").select("agency_id,role").eq("id", user.id).maybeSingle();
  if (!owner || owner.role !== "owner") return new Response("Forbidden", { status: 403 });

  const body = await req.json();
  const username = String(body.username ?? "").trim();
  const password = String(body.password ?? "");
  const role = String(body.role ?? "");
  const clientId = body.client_id ?? null;
  const permissions = body.permissions ?? {};
  if (!username || password.length < 6 || !["media_buyer","client"].includes(role)) {
    return new Response("Invalid input", { status: 400 });
  }

  const syntheticEmail = username.toLowerCase().replace(/[^a-z0-9._-]+/g, "-") + "@auth.poost.app";
  const created = await admin.auth.admin.createUser({
    email: syntheticEmail,
    password,
    email_confirm: true,
    user_metadata: { username, role }
  });
  if (created.error) return new Response(created.error.message, { status: 400 });

  const profile = await admin.from("profiles").insert({
    id: created.data.user.id,
    agency_id: owner.agency_id,
    full_name: username,
    role,
    client_id: clientId,
    permissions
  });
  if (profile.error) {
    await admin.auth.admin.deleteUser(created.data.user.id);
    return new Response(profile.error.message, { status: 400 });
  }
  return Response.json({ ok: true, user_id: created.data.user.id });
});
